import { createClient } from "npm:@supabase/supabase-js@2";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const textEncoder = new TextEncoder();
const supportedProviders = ["google", "microsoft"] as const;

export type SupportedEmailProvider = (typeof supportedProviders)[number];

interface ProviderConfig {
  provider: SupportedEmailProvider;
  clientId: string;
  clientSecret: string;
  authUrl: string;
  tokenUrl: string;
  redirectUri: string;
  scopes: string[];
}

export interface AdminContext {
  userId: string;
  companyId: string;
  email: string | null;
  role: string;
}

interface RequireAdminContextOptions {
  nonAdminMessage?: string;
}

export interface OAuthStatePayload {
  provider: SupportedEmailProvider;
  userId: string;
  companyId: string;
  issuedAt: number;
  expiresAt: number;
  nonce: string;
  returnTo?: string;
}

export interface OAuthTokenSet {
  accessToken: string;
  refreshToken: string | null;
  tokenType: string | null;
  expiresAt: string | null;
  scope: string[];
  idToken: string | null;
  rawPayload: Record<string, unknown>;
}

export interface ProviderIdentity {
  provider: SupportedEmailProvider;
  providerUserId: string;
  email: string;
  displayName: string | null;
  metadata: Record<string, unknown>;
}

export function jsonResponse(
  body: unknown,
  status = 200,
  extraHeaders: Record<string, string> = {},
) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      ...extraHeaders,
    },
  });
}

export function htmlResponse(body: string, status = 200) {
  return new Response(body, {
    status,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

export function isSupportedEmailProvider(
  value: string,
): value is SupportedEmailProvider {
  return supportedProviders.includes(value as SupportedEmailProvider);
}

export async function parseJsonBody(req: Request) {
  try {
    const body = await req.json();
    return body && typeof body === "object"
      ? (body as Record<string, unknown>)
      : {};
  } catch (_) {
    return {};
  }
}

export function buildProviderLabel(provider: SupportedEmailProvider) {
  return provider === "google"
    ? "Google / Gmail"
    : "Microsoft / Hotmail / Outlook";
}

function isBlank(value: string | null | undefined) {
  return value == null || value.trim().length === 0;
}

export function resolveCallbackUrl(req: Request) {
  const configured = Deno.env.get("EMAIL_PROVIDER_CALLBACK_URL")?.trim();
  if (!isBlank(configured)) {
    return configured!;
  }

  return `${new URL(req.url).origin}/functions/v1/email-provider-callback`;
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (isBlank(value)) {
    throw new Error(`Missing environment variable ${name}.`);
  }
  return value!;
}

function createAuthClient(authHeader?: string | null) {
  const normalizedAuthHeader = authHeader?.trim() ?? "";
  return createClient(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_ANON_KEY"),
    {
      auth: { persistSession: false, autoRefreshToken: false },
      global: isBlank(normalizedAuthHeader)
        ? {}
        : { headers: { Authorization: normalizedAuthHeader } },
    },
  );
}

export function createServiceClient() {
  return createClient(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
    {
      auth: { persistSession: false, autoRefreshToken: false },
    },
  );
}

export async function requireAdminContext(
  req: Request,
  options?: RequireAdminContextOptions,
): Promise<AdminContext> {
  const authHeader = req.headers.get("Authorization");
  if (isBlank(authHeader)) {
    throw new Error("Missing Authorization header.");
  }

  const authClient = createAuthClient(authHeader);
  const {
    data: { user },
    error: userError,
  } = await authClient.auth.getUser();

  if (userError != null || user == null) {
    throw new Error("Nao foi possivel validar o utilizador autenticado.");
  }

  const serviceClient = createServiceClient();
  const { data: profile, error: profileError } = await serviceClient
    .from("profiles")
    .select("id, role, company_id, email")
    .eq("id", user.id)
    .maybeSingle();

  if (profileError != null || profile == null) {
    throw new Error("Perfil do utilizador nao encontrado.");
  }

  const role = profile["role"]?.toString().trim().toLowerCase() ?? "";
  const companyId = profile["company_id"]?.toString().trim() ?? "";
  if (role != "admin") {
    throw new Error(
      options?.nonAdminMessage ??
        "Apenas administradores podem ligar contas de email.",
    );
  }
  if (companyId.length === 0) {
    throw new Error("A empresa atual do administrador nao esta definida.");
  }

  return {
    userId: user.id,
    companyId,
    email: profile["email"]?.toString().trim() ?? user.email ?? null,
    role,
  };
}

function providerConfig(
  provider: SupportedEmailProvider,
  req: Request,
): ProviderConfig {
  const redirectUri = resolveCallbackUrl(req);

  if (provider === "google") {
    return {
      provider,
      clientId: requiredEnv("GOOGLE_OAUTH_CLIENT_ID"),
      clientSecret: requiredEnv("GOOGLE_OAUTH_CLIENT_SECRET"),
      authUrl: "https://accounts.google.com/o/oauth2/v2/auth",
      tokenUrl: "https://oauth2.googleapis.com/token",
      redirectUri,
      scopes: [
        "openid",
        "email",
        "profile",
        "https://www.googleapis.com/auth/gmail.send",
      ],
    };
  }

  const tenantId = Deno.env.get("MICROSOFT_OAUTH_TENANT_ID")?.trim() ||
    "common";
  return {
    provider,
    clientId: requiredEnv("MICROSOFT_OAUTH_CLIENT_ID"),
    clientSecret: requiredEnv("MICROSOFT_OAUTH_CLIENT_SECRET"),
    authUrl: `https://login.microsoftonline.com/${tenantId}/oauth2/v2.0/authorize`,
    tokenUrl: `https://login.microsoftonline.com/${tenantId}/oauth2/v2.0/token`,
    redirectUri,
    scopes: [
      "offline_access",
      "openid",
      "profile",
      "email",
      "User.Read",
      "Mail.Send",
    ],
  };
}

function base64UrlEncode(input: string) {
  const bytes = textEncoder.encode(input);
  let binary = "";
  for (const value of bytes) {
    binary += String.fromCharCode(value);
  }

  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll(
    "=",
    "",
  );
}

function base64UrlDecode(input: string) {
  const normalized = input.replaceAll("-", "+").replaceAll("_", "/");
  const padding = normalized.length % 4 == 0
    ? ""
    : "=".repeat(4 - (normalized.length % 4));
  const binary = atob(`${normalized}${padding}`);
  const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}

async function signValue(value: string) {
  const secret = requiredEnv("EMAIL_PROVIDER_STATE_SECRET");
  const key = await crypto.subtle.importKey(
    "raw",
    textEncoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    textEncoder.encode(value),
  );
  return btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

export async function createStateToken(payload: OAuthStatePayload) {
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const signature = await signValue(encodedPayload);
  return `${encodedPayload}.${signature}`;
}

export async function verifyStateToken(
  stateToken: string,
): Promise<OAuthStatePayload> {
  const [encodedPayload, providedSignature] = stateToken.split(".");
  if (
    encodedPayload == null ||
    encodedPayload.length === 0 ||
    providedSignature == null ||
    providedSignature.length === 0
  ) {
    throw new Error("State OAuth invalido.");
  }

  const expectedSignature = await signValue(encodedPayload);
  if (expectedSignature != providedSignature) {
    throw new Error("Assinatura do state OAuth invalida.");
  }

  const payload = JSON.parse(base64UrlDecode(encodedPayload));
  if (payload == null || typeof payload !== "object") {
    throw new Error("Payload OAuth invalido.");
  }

  const normalizedPayload = payload as Partial<OAuthStatePayload>;
  if (
    normalizedPayload.provider == null ||
    !isSupportedEmailProvider(normalizedPayload.provider)
  ) {
    throw new Error("Provider OAuth invalido.");
  }

  const expiresAt = Number(normalizedPayload.expiresAt ?? 0);
  if (!Number.isFinite(expiresAt) || Date.now() > expiresAt) {
    throw new Error("State OAuth expirado.");
  }

  return {
    provider: normalizedPayload.provider,
    userId: normalizedPayload.userId?.toString() ?? "",
    companyId: normalizedPayload.companyId?.toString() ?? "",
    issuedAt: Number(normalizedPayload.issuedAt ?? 0),
    expiresAt,
    nonce: normalizedPayload.nonce?.toString() ?? "",
    returnTo: normalizedPayload.returnTo?.toString(),
  };
}

export async function buildAuthorizationUrl(
  provider: SupportedEmailProvider,
  req: Request,
  stateToken: string,
) {
  const config = providerConfig(provider, req);
  const url = new URL(config.authUrl);

  url.searchParams.set("client_id", config.clientId);
  url.searchParams.set("redirect_uri", config.redirectUri);
  url.searchParams.set("response_type", "code");
  url.searchParams.set("scope", config.scopes.join(" "));
  url.searchParams.set("state", stateToken);

  if (provider === "google") {
    url.searchParams.set("access_type", "offline");
    url.searchParams.set("include_granted_scopes", "true");
    url.searchParams.set("prompt", "consent");
  } else {
    url.searchParams.set("response_mode", "query");
  }

  return url.toString();
}

export async function exchangeAuthorizationCode(
  provider: SupportedEmailProvider,
  code: string,
  req: Request,
): Promise<OAuthTokenSet> {
  const config = providerConfig(provider, req);
  const body = new URLSearchParams({
    client_id: config.clientId,
    client_secret: config.clientSecret,
    code,
    grant_type: "authorization_code",
    redirect_uri: config.redirectUri,
  });

  const response = await fetch(config.tokenUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body,
  });

  const payload = await response.json();
  if (!response.ok) {
    const description =
      payload?.error_description?.toString().trim() ??
      payload?.error?.toString().trim() ??
      "Falha ao trocar o authorization code por tokens.";
    throw new Error(description);
  }

  const expiresIn = Number(payload?.expires_in ?? 0);
  const expiresAt = Number.isFinite(expiresIn) && expiresIn > 0
    ? new Date(Date.now() + (expiresIn * 1000)).toISOString()
    : null;
  const scopeText = payload?.scope?.toString().trim() ?? "";

  return {
    accessToken: payload?.access_token?.toString().trim() ?? "",
    refreshToken: payload?.refresh_token?.toString().trim() ?? null,
    tokenType: payload?.token_type?.toString().trim() ?? null,
    expiresAt,
    scope: scopeText.length === 0 ? config.scopes : scopeText.split(/\s+/),
    idToken: payload?.id_token?.toString().trim() ?? null,
    rawPayload: payload as Record<string, unknown>,
  };
}

export async function fetchProviderIdentity(
  provider: SupportedEmailProvider,
  accessToken: string,
): Promise<ProviderIdentity> {
  if (provider === "google") {
    const response = await fetch(
      "https://openidconnect.googleapis.com/v1/userinfo",
      {
        headers: { Authorization: `Bearer ${accessToken}` },
      },
    );
    const payload = await response.json();
    if (!response.ok) {
      throw new Error("Nao foi possivel obter a identidade Google.");
    }

    const email = payload?.email?.toString().trim() ?? "";
    if (email.length === 0) {
      throw new Error("A conta Google autenticada nao devolveu um email.");
    }

    return {
      provider,
      providerUserId: payload?.sub?.toString().trim() ?? email,
      email,
      displayName: payload?.name?.toString().trim() ?? null,
      metadata: {
        email_verified: payload?.email_verified ?? null,
        picture: payload?.picture ?? null,
      },
    };
  }

  const response = await fetch(
    "https://graph.microsoft.com/v1.0/me?$select=id,displayName,mail,userPrincipalName",
    {
      headers: { Authorization: `Bearer ${accessToken}` },
    },
  );
  const payload = await response.json();
  if (!response.ok) {
    throw new Error("Nao foi possivel obter a identidade Microsoft.");
  }

  const email = payload?.mail?.toString().trim() ??
    payload?.userPrincipalName?.toString().trim() ?? "";
  if (email.length === 0) {
    throw new Error("A conta Microsoft autenticada nao devolveu um email.");
  }

  return {
    provider,
    providerUserId: payload?.id?.toString().trim() ?? email,
    email,
    displayName: payload?.displayName?.toString().trim() ?? null,
    metadata: {
      user_principal_name: payload?.userPrincipalName ?? null,
    },
  };
}

export async function upsertCompanyEmailConnection(params: {
  context: AdminContext;
  provider: SupportedEmailProvider;
  identity: ProviderIdentity;
  tokenSet: OAuthTokenSet;
}) {
  const { context, provider, identity, tokenSet } = params;
  const serviceClient = createServiceClient();
  const nowIso = new Date().toISOString();

  const { data: connection, error: connectionError } = await serviceClient
    .from("company_email_connections")
    .upsert(
      {
        company_id: context.companyId,
        provider,
        email: identity.email,
        display_name: identity.displayName,
        status: "connected",
        external_account_id: identity.providerUserId,
        access_scope: tokenSet.scope,
        connected_at: nowIso,
        last_sync_at: nowIso,
        last_error: null,
        metadata: identity.metadata,
        created_by: context.userId,
      },
      {
        onConflict: "company_id,provider,email",
      },
    )
    .select()
    .single();

  if (connectionError != null || connection == null) {
    throw new Error("Nao foi possivel guardar a conta ligada da empresa.");
  }

  let refreshToken = tokenSet.refreshToken;
  if (isBlank(refreshToken)) {
    const { data: existingCredentials } = await serviceClient
      .from("company_email_connection_credentials")
      .select("refresh_token")
      .eq("connection_id", connection["id"])
      .maybeSingle();
    refreshToken = existingCredentials?.["refresh_token"]?.toString().trim();
  }

  if (isBlank(refreshToken)) {
    throw new Error(
      "O provider nao devolveu refresh token e nao existia um token anterior para reutilizar.",
    );
  }
  const normalizedRefreshToken = refreshToken!;

  const { error: credentialError } = await serviceClient
    .from("company_email_connection_credentials")
    .upsert(
      {
        connection_id: connection["id"],
        provider,
        refresh_token: normalizedRefreshToken,
        access_token: tokenSet.accessToken,
        token_type: tokenSet.tokenType,
        id_token: tokenSet.idToken,
        expires_at: tokenSet.expiresAt,
        access_scope: tokenSet.scope,
        raw_payload: tokenSet.rawPayload,
      },
      { onConflict: "connection_id" },
    );

  if (credentialError != null) {
    throw new Error("Nao foi possivel guardar as credenciais OAuth.");
  }

  const {
    data: existingCompanyProfile,
    error: companyProfileLookupError,
  } = await serviceClient
    .from("company_profile")
    .select("id")
    .eq("company_id", context.companyId)
    .maybeSingle();

  if (companyProfileLookupError != null) {
    throw new Error(
      "A conta foi ligada, mas nao foi possivel localizar o perfil da empresa.",
    );
  }

  if (existingCompanyProfile != null) {
    const { error: profileUpdateError } = await serviceClient
      .from("company_profile")
      .update({
        authorization_email_provider: provider,
        authorization_email_connection_id: connection["id"],
        updated_at: nowIso,
      })
      .eq("id", existingCompanyProfile["id"]);

    if (profileUpdateError != null) {
      throw new Error(
        "A conta foi ligada, mas nao foi possivel atualizar o perfil da empresa.",
      );
    }
  } else {
    const { data: company, error: companyLookupError } = await serviceClient
      .from("companies")
      .select("display_name, legal_name")
      .eq("id", context.companyId)
      .maybeSingle();

    if (companyLookupError != null) {
      throw new Error(
        "A conta foi ligada, mas nao foi possivel obter os dados base da empresa.",
      );
    }

    const companyDisplayName = company?.["display_name"]?.toString().trim() ??
      "";
    const companyLegalName = company?.["legal_name"]?.toString().trim() ?? "";
    const fallbackName = companyDisplayName ||
      companyLegalName ||
      context.email ||
      identity.email;

    const { error: profileInsertError } = await serviceClient
      .from("company_profile")
      .insert({
        company_id: context.companyId,
        name: fallbackName,
        legal_name: companyLegalName || fallbackName,
        email: context.email ?? identity.email,
        authorization_email_provider: provider,
        authorization_email_connection_id: connection["id"],
        updated_at: nowIso,
      });

    if (profileInsertError != null) {
      throw new Error(
        "A conta foi ligada, mas nao foi possivel criar o perfil da empresa para guardar esta associacao.",
      );
    }
  }

  return {
    connectionId: connection["id"]?.toString() ?? "",
    email: identity.email,
    displayName: identity.displayName,
  };
}

export function renderCallbackResultHtml(params: {
  success: boolean;
  title: string;
  message: string;
}) {
  const accent = params.success ? "#166534" : "#991b1b";
  const background = params.success ? "#ecfdf5" : "#fef2f2";
  const border = params.success ? "#86efac" : "#fca5a5";
  return `<!doctype html>
<html lang="pt">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${params.title}</title>
    <style>
      body {
        margin: 0;
        font-family: Arial, sans-serif;
        background: #f5f7fb;
        color: #0f172a;
      }
      main {
        max-width: 720px;
        margin: 48px auto;
        padding: 0 16px;
      }
      .card {
        background: white;
        border: 1px solid #dbe4f0;
        border-radius: 20px;
        padding: 24px;
        box-shadow: 0 18px 40px rgba(15, 23, 42, 0.08);
      }
      .status {
        background: ${background};
        border: 1px solid ${border};
        color: ${accent};
        border-radius: 14px;
        padding: 14px 16px;
        margin-top: 16px;
      }
      h1 {
        margin: 0;
        font-size: 24px;
      }
      p {
        line-height: 1.5;
      }
    </style>
  </head>
  <body>
    <main>
      <div class="card">
        <h1>${params.title}</h1>
        <div class="status">${params.message}</div>
        <p>Podes fechar esta pagina e voltar a app. Depois carrega em "Atualizar contas" na configuracao de email.</p>
      </div>
    </main>
  </body>
</html>`;
}

export function buildReturnUrl(
  returnTo: string | undefined,
  params: Record<string, string>,
) {
  const base = returnTo?.trim();
  if (isBlank(base)) {
    return null;
  }

  try {
    const url = new URL(base!);
    for (const [key, value] of Object.entries(params)) {
      url.searchParams.set(key, value);
    }
    return url.toString();
  } catch (_) {
    return null;
  }
}
