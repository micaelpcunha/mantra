import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

function requiredEnv(name: string) {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function createRequestClient(req: Request) {
  return createClient(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_ANON_KEY"),
    {
      global: {
        headers: {
          Authorization: req.headers.get("Authorization") ?? "",
        },
      },
    },
  );
}

function createServiceClient() {
  return createClient(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
  );
}

function normalizeText(value: unknown) {
  const text = value?.toString().trim() ?? "";
  return text.length === 0 ? null : text;
}

function buildSlugSeed(companyName: string) {
  const normalized = companyName
    .toLowerCase()
    .normalize("NFD")
    .replaceAll(/[\u0300-\u036f]/g, "")
    .replaceAll(/[^a-z0-9]+/g, "-")
    .replaceAll(/^-+|-+$/g, "");
  return normalized.length === 0 ? "empresa" : normalized;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  try {
    const requestClient = createRequestClient(req);
    const serviceClient = createServiceClient();
    const {
      data: { user },
      error: userError,
    } = await requestClient.auth.getUser();

    if (userError != null || user == null) {
      return jsonResponse({ error: "Sessao invalida." }, 401);
    }

    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const fullName = normalizeText(body["full_name"]) ??
      normalizeText(user.user_metadata?.["full_name"]);
    const companyName = normalizeText(body["company_name"]) ??
      normalizeText(user.user_metadata?.["pending_company_name"]);

    if (fullName == null) {
      return jsonResponse({ error: "Indica o nome completo." }, 400);
    }

    if (companyName == null) {
      return jsonResponse({ error: "Indica o nome da empresa." }, 400);
    }

    const userEmail = normalizeText(user.email);
    if (userEmail == null) {
      return jsonResponse(
        { error: "Nao foi possivel obter o email da conta autenticada." },
        400,
      );
    }

    const { data: existingProfile, error: profileError } = await serviceClient
      .from("profiles")
      .select("id, company_id")
      .eq("id", user.id)
      .maybeSingle();

    if (profileError != null) {
      throw profileError;
    }

    const existingCompanyId = normalizeText(existingProfile?.["company_id"]);
    if (existingCompanyId != null) {
      return jsonResponse(
        { error: "Esta conta ja esta associada a uma empresa." },
        409,
      );
    }

    const slug = `${buildSlugSeed(companyName)}-${
      crypto.randomUUID().replaceAll("-", "").slice(0, 8)
    }`;

    const { data: company, error: companyError } = await serviceClient
      .from("companies")
      .insert({
        slug,
        display_name: companyName,
        legal_name: companyName,
        onboarding_status: "active",
        settings: {
          signup_source: "self_service",
          product_ready: true,
        },
      })
      .select("id")
      .single();

    if (companyError != null || company == null) {
      throw companyError ?? new Error("Nao foi possivel criar a empresa.");
    }

    const companyId = company["id"]?.toString();
    if (companyId == null || companyId.trim().length === 0) {
      throw new Error("A empresa foi criada sem identificador valido.");
    }

    const { error: profileUpsertError } = await serviceClient
      .from("profiles")
      .upsert({
        id: user.id,
        email: userEmail,
        full_name: fullName,
        role: "admin",
        technician_id: null,
        company_id: companyId,
      });

    if (profileUpsertError != null) {
      throw profileUpsertError;
    }

    const { data: companyProfile, error: companyProfileLookupError } =
      await serviceClient
        .from("company_profile")
        .select("id")
        .eq("company_id", companyId)
        .limit(1)
        .maybeSingle();

    if (companyProfileLookupError != null) {
      throw companyProfileLookupError;
    }

    if (companyProfile == null) {
      const { error: companyProfileInsertError } = await serviceClient
        .from("company_profile")
        .insert({
          company_id: companyId,
          name: companyName,
          legal_name: companyName,
          email: userEmail,
        });

      if (companyProfileInsertError != null) {
        throw companyProfileInsertError;
      }
    } else {
      const { error: companyProfileUpdateError } = await serviceClient
        .from("company_profile")
        .update({
          name: companyName,
          legal_name: companyName,
          email: userEmail,
          updated_at: new Date().toISOString(),
        })
        .eq("id", companyProfile["id"]);

      if (companyProfileUpdateError != null) {
        throw companyProfileUpdateError;
      }
    }

    const existingMetadata = user.user_metadata ?? {};
    const {
      pending_company_name: _pendingCompanyName,
      ...nextMetadata
    } = {
      ...existingMetadata,
      full_name: fullName,
      role: "admin",
      company_id: companyId,
    };

    const { error: authUpdateError } = await serviceClient.auth.admin
      .updateUserById(user.id, {
        user_metadata: nextMetadata,
      });

    if (authUpdateError != null) {
      throw authUpdateError;
    }

    return jsonResponse({
      company_id: companyId,
      company_name: companyName,
      role: "admin",
    });
  } catch (error) {
    const message = error instanceof Error
      ? error.message
      : "Nao foi possivel concluir a criacao da empresa.";
    return jsonResponse({ error: message }, 400);
  }
});
