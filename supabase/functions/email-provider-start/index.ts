import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  buildAuthorizationUrl,
  buildProviderLabel,
  corsHeaders,
  createStateToken,
  isSupportedEmailProvider,
  jsonResponse,
  parseJsonBody,
  requireAdminContext,
} from "../_shared/email_provider_oauth.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  try {
    const context = await requireAdminContext(req);
    const body = await parseJsonBody(req);
    const provider = body["provider"]?.toString().trim().toLowerCase() ?? "";
    const returnTo = body["return_to"]?.toString().trim();

    if (!isSupportedEmailProvider(provider)) {
      return jsonResponse(
        { error: "Provider invalido. Usa google ou microsoft." },
        400,
      );
    }

    const stateToken = await createStateToken({
      provider,
      userId: context.userId,
      companyId: context.companyId,
      issuedAt: Date.now(),
      expiresAt: Date.now() + (15 * 60 * 1000),
      nonce: crypto.randomUUID(),
      returnTo,
    });

    const authorizationUrl = await buildAuthorizationUrl(
      provider,
      req,
      stateToken,
    );

    return jsonResponse({
      provider,
      provider_label: buildProviderLabel(provider),
      authorization_url: authorizationUrl,
    });
  } catch (error) {
    return jsonResponse(
      {
        error: error instanceof Error
          ? error.message
          : "Falha ao iniciar a autenticacao OAuth.",
      },
      400,
    );
  }
});
