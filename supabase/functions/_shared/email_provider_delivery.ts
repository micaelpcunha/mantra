import type { OAuthTokenSet, SupportedEmailProvider } from "./email_provider_oauth.ts";

const textEncoder = new TextEncoder();

function isBlank(value: string | null | undefined) {
  return value == null || value.trim().length === 0;
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (isBlank(value)) {
    throw new Error(`Missing environment variable ${name}.`);
  }
  return value!;
}

function providerTokenConfig(provider: SupportedEmailProvider) {
  if (provider === "google") {
    return {
      clientId: requiredEnv("GOOGLE_OAUTH_CLIENT_ID"),
      clientSecret: requiredEnv("GOOGLE_OAUTH_CLIENT_SECRET"),
      tokenUrl: "https://oauth2.googleapis.com/token",
    };
  }

  const tenantId = Deno.env.get("MICROSOFT_OAUTH_TENANT_ID")?.trim() ||
    "common";
  return {
    clientId: requiredEnv("MICROSOFT_OAUTH_CLIENT_ID"),
    clientSecret: requiredEnv("MICROSOFT_OAUTH_CLIENT_SECRET"),
    tokenUrl: `https://login.microsoftonline.com/${tenantId}/oauth2/v2.0/token`,
  };
}

export interface AuthorizationEmailSendDraft {
  assetId: string | null;
  recipientEmail: string;
  subject: string;
  body: string;
}

export interface ProviderEmailSendResult {
  providerMessageId: string | null;
  rawResponse: Record<string, unknown>;
}

async function decodeErrorPayload(response: Response) {
  const contentType = response.headers.get("content-type")?.toLowerCase() ?? "";
  if (contentType.includes("application/json")) {
    try {
      return await response.json();
    } catch (_) {
      return null;
    }
  }

  try {
    return await response.text();
  } catch (_) {
    return null;
  }
}

function base64EncodeUtf8(value: string) {
  const bytes = textEncoder.encode(value);
  let binary = "";
  for (const value of bytes) {
    binary += String.fromCharCode(value);
  }
  return btoa(binary);
}

function base64UrlEncodeBytes(bytes: Uint8Array) {
  let binary = "";
  for (const value of bytes) {
    binary += String.fromCharCode(value);
  }
  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

function encodeMimeHeader(value: string) {
  if (/^[\x20-\x7E]*$/.test(value)) {
    return value;
  }
  return `=?UTF-8?B?${base64EncodeUtf8(value)}?=`;
}

function buildGmailRawMessage(params: {
  recipientEmail: string;
  subject: string;
  body: string;
  replyToEmail?: string | null;
}) {
  const lines = [
    `To: ${params.recipientEmail}`,
    `Subject: ${encodeMimeHeader(params.subject)}`,
    "MIME-Version: 1.0",
    'Content-Type: text/plain; charset="UTF-8"',
    "Content-Transfer-Encoding: 8bit",
  ];

  const replyToEmail = params.replyToEmail?.trim();
  if (!isBlank(replyToEmail)) {
    lines.splice(1, 0, `Reply-To: ${replyToEmail}`);
  }

  const message = `${lines.join("\r\n")}\r\n\r\n${params.body}`;
  return base64UrlEncodeBytes(textEncoder.encode(message));
}

function extractProviderErrorMessage(payload: unknown) {
  if (payload != null && typeof payload === "object") {
    const map = payload as Record<string, unknown>;
    const directError = map["error"];
    if (typeof directError === "string" && directError.trim().length > 0) {
      return directError.trim();
    }

    if (directError != null && typeof directError === "object") {
      const nested = directError as Record<string, unknown>;
      const nestedMessage = nested["message"]?.toString().trim();
      if (nestedMessage != null && nestedMessage.length > 0) {
        return nestedMessage;
      }
      const nestedDescription = nested["error_description"]?.toString().trim();
      if (nestedDescription != null && nestedDescription.length > 0) {
        return nestedDescription;
      }
    }

    const message = map["message"]?.toString().trim();
    if (message != null && message.length > 0) {
      return message;
    }

    const description = map["error_description"]?.toString().trim();
    if (description != null && description.length > 0) {
      return description;
    }
  }

  const fallback = payload?.toString().trim();
  return fallback == null || fallback.length === 0 ? null : fallback;
}

export function isReauthErrorMessage(message: string) {
  const normalized = message.toLowerCase();
  return normalized.includes("invalid_grant") ||
    normalized.includes("reauth") ||
    normalized.includes("revoked") ||
    normalized.includes("expired") ||
    normalized.includes("unauthorized") ||
    normalized.includes("invalid credentials") ||
    normalized.includes("insufficient authentication");
}

export async function refreshProviderAccessToken(
  provider: SupportedEmailProvider,
  refreshToken: string,
): Promise<OAuthTokenSet> {
  const config = providerTokenConfig(provider);
  const body = new URLSearchParams({
    client_id: config.clientId,
    client_secret: config.clientSecret,
    refresh_token: refreshToken,
    grant_type: "refresh_token",
  });

  const response = await fetch(config.tokenUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body,
  });

  const payload = await decodeErrorPayload(response);
  if (!response.ok) {
    const description = extractProviderErrorMessage(payload) ??
      "Falha ao renovar o access token OAuth.";
    throw new Error(description);
  }

  const data = payload != null && typeof payload === "object"
    ? payload as Record<string, unknown>
    : {};
  const expiresIn = Number(data["expires_in"] ?? 0);
  const expiresAt = Number.isFinite(expiresIn) && expiresIn > 0
    ? new Date(Date.now() + (expiresIn * 1000)).toISOString()
    : null;
  const scopeText = data["scope"]?.toString().trim() ?? "";

  return {
    accessToken: data["access_token"]?.toString().trim() ?? "",
    refreshToken: data["refresh_token"]?.toString().trim() ?? refreshToken,
    tokenType: data["token_type"]?.toString().trim() ?? null,
    expiresAt,
    scope: scopeText.length === 0 ? [] : scopeText.split(/\s+/),
    idToken: data["id_token"]?.toString().trim() ?? null,
    rawPayload: data,
  };
}

export async function sendProviderEmail(params: {
  provider: SupportedEmailProvider;
  accessToken: string;
  recipientEmail: string;
  subject: string;
  body: string;
  replyToEmail?: string | null;
}): Promise<ProviderEmailSendResult> {
  if (params.provider === "google") {
    const response = await fetch(
      "https://gmail.googleapis.com/gmail/v1/users/me/messages/send",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${params.accessToken}`,
          "Content-Type": "application/json; charset=utf-8",
        },
        body: JSON.stringify({
          raw: buildGmailRawMessage(
            {
              recipientEmail: params.recipientEmail,
              subject: params.subject,
              body: params.body,
              replyToEmail: params.replyToEmail,
            },
          ),
        }),
      },
    );

    const payload = await decodeErrorPayload(response);
    if (!response.ok) {
      throw new Error(
        extractProviderErrorMessage(payload) ??
          "Falha ao enviar o email pelo Gmail.",
      );
    }

    const data = payload != null && typeof payload === "object"
      ? payload as Record<string, unknown>
      : {};
    return {
      providerMessageId: data["id"]?.toString().trim() ?? null,
      rawResponse: data,
    };
  }

  const response = await fetch("https://graph.microsoft.com/v1.0/me/sendMail", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${params.accessToken}`,
      "Content-Type": "application/json; charset=utf-8",
    },
    body: JSON.stringify({
      message: {
        subject: params.subject,
        body: {
          contentType: "Text",
          content: params.body,
        },
        toRecipients: [
          {
            emailAddress: {
              address: params.recipientEmail,
            },
          },
        ],
        ...(isBlank(params.replyToEmail)
            ? {}
            : {
              replyTo: [
                {
                  emailAddress: {
                    address: params.replyToEmail!.trim(),
                  },
                },
              ],
            }),
      },
      saveToSentItems: true,
    }),
  });

  const payload = await decodeErrorPayload(response);
  if (!response.ok) {
    throw new Error(
      extractProviderErrorMessage(payload) ??
        "Falha ao enviar o email pela conta Microsoft.",
    );
  }

  return {
    providerMessageId: response.headers.get("x-ms-request-id"),
    rawResponse: payload != null && typeof payload === "object"
      ? payload as Record<string, unknown>
      : {},
  };
}
