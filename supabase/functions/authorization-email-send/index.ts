import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  corsHeaders,
  createServiceClient,
  isSupportedEmailProvider,
  jsonResponse,
  parseJsonBody,
  requireAdminContext,
  type SupportedEmailProvider,
} from "../_shared/email_provider_oauth.ts";
import {
  isReauthErrorMessage,
  refreshProviderAccessToken,
  sendProviderEmail,
  type AuthorizationEmailSendDraft,
} from "../_shared/email_provider_delivery.ts";

interface AuthorizationEmailSendItemResult {
  asset_id: string | null;
  recipient_email: string;
  subject: string;
  status: "sent" | "failed";
  provider_message_id: string | null;
  error_message: string | null;
}

function normalizedText(value: unknown) {
  const text = value?.toString().trim() ?? "";
  return text.length === 0 ? null : text;
}

function normalizePlannedDate(value: unknown) {
  const text = normalizedText(value);
  if (text == null) {
    return null;
  }

  return /^\d{4}-\d{2}-\d{2}$/.test(text) ? text : null;
}

function normalizeDrafts(body: Record<string, unknown>) {
  const rawDrafts = body["drafts"];
  if (!Array.isArray(rawDrafts)) {
    return [] as AuthorizationEmailSendDraft[];
  }

  return rawDrafts
    .map((item) => {
      if (item == null || typeof item !== "object") {
        return null;
      }

      const draft = item as Record<string, unknown>;
      const recipientEmail = normalizedText(draft["recipient_email"]);
      const subject = normalizedText(draft["subject"]);
      const bodyText = normalizedText(draft["body"]);

      if (recipientEmail == null || subject == null || bodyText == null) {
        return null;
      }

      return {
        assetId: normalizedText(draft["asset_id"]),
        recipientEmail,
        subject,
        body: bodyText,
      } as AuthorizationEmailSendDraft;
    })
    .filter((draft): draft is AuthorizationEmailSendDraft => draft != null);
}

async function updateConnectionStatus(params: {
  connectionId: string;
  status: "connected" | "needs_reauth" | "error";
  lastError: string | null;
  markSynced: boolean;
}) {
  const serviceClient = createServiceClient();
  const nowIso = new Date().toISOString();

  await serviceClient
    .from("company_email_connections")
    .update({
      status: params.status,
      last_error: params.lastError,
      last_test_at: nowIso,
      ...(params.markSynced ? { last_sync_at: nowIso } : {}),
    })
    .eq("id", params.connectionId);
}

async function persistCredentialRefresh(params: {
  connectionId: string;
  provider: SupportedEmailProvider;
  refreshToken: string;
  tokenSet: Awaited<ReturnType<typeof refreshProviderAccessToken>>;
}) {
  const serviceClient = createServiceClient();
  await serviceClient
    .from("company_email_connection_credentials")
    .upsert({
      connection_id: params.connectionId,
      provider: params.provider,
      refresh_token: params.tokenSet.refreshToken ?? params.refreshToken,
      access_token: params.tokenSet.accessToken,
      token_type: params.tokenSet.tokenType,
      id_token: params.tokenSet.idToken,
      expires_at: params.tokenSet.expiresAt,
      access_scope: params.tokenSet.scope,
      raw_payload: params.tokenSet.rawPayload,
    }, { onConflict: "connection_id" });
}

async function insertDeliveryLog(params: {
  companyId: string;
  connectionId: string;
  createdBy: string;
  plannedFor: string | null;
  result: AuthorizationEmailSendItemResult;
  metadata?: Record<string, unknown>;
}) {
  const serviceClient = createServiceClient();
  await serviceClient
    .from("authorization_email_delivery_logs")
    .insert({
      company_id: params.companyId,
      connection_id: params.connectionId,
      asset_id: params.result.asset_id,
      planned_for: params.plannedFor,
      recipient_email: params.result.recipient_email,
      subject: params.result.subject,
      status: params.result.status,
      provider_message_id: params.result.provider_message_id,
      error_message: params.result.error_message,
      metadata: params.metadata ?? {},
      created_by: params.createdBy,
    });
}

async function logFailureForAllDrafts(params: {
  companyId: string;
  connectionId: string;
  createdBy: string;
  plannedFor: string | null;
  drafts: AuthorizationEmailSendDraft[];
  message: string;
}) {
  for (const draft of params.drafts) {
    await insertDeliveryLog({
      companyId: params.companyId,
      connectionId: params.connectionId,
      createdBy: params.createdBy,
      plannedFor: params.plannedFor,
      result: {
        asset_id: draft.assetId,
        recipient_email: draft.recipientEmail,
        subject: draft.subject,
        status: "failed",
        provider_message_id: null,
        error_message: params.message,
      },
    });
  }
}

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
    const drafts = normalizeDrafts(body);
    if (drafts.length === 0) {
      return jsonResponse(
        { error: "Indica pelo menos um email valido para enviar." },
        400,
      );
    }

    const requestedConnectionId = normalizedText(body["connection_id"]);
    const plannedFor = normalizePlannedDate(body["planned_date"]);
    const serviceClient = createServiceClient();

    const { data: profile, error: profileError } = await serviceClient
      .from("company_profile")
      .select(
        "authorization_email_provider, authorization_email_connection_id, authorization_sender_email",
      )
      .eq("company_id", context.companyId)
      .maybeSingle();

    if (profileError != null) {
      throw new Error("Nao foi possivel resolver a configuracao da empresa.");
    }

    const connectionId = requestedConnectionId ??
      normalizedText(profile?.["authorization_email_connection_id"]);
    if (connectionId == null) {
      throw new Error("A empresa ainda nao tem nenhuma conta de envio ligada.");
    }

    const { data: connection, error: connectionError } = await serviceClient
      .from("company_email_connections")
      .select("id, provider, email, status")
      .eq("id", connectionId)
      .eq("company_id", context.companyId)
      .maybeSingle();

    if (connectionError != null || connection == null) {
      throw new Error("A conta de envio configurada nao foi encontrada.");
    }

    const provider = normalizedText(connection["provider"])?.toLowerCase() ?? "";
    if (!isSupportedEmailProvider(provider)) {
      throw new Error("O provider configurado nao e suportado para envio.");
    }

    const { data: credentials, error: credentialsError } = await serviceClient
      .from("company_email_connection_credentials")
      .select("refresh_token")
      .eq("connection_id", connectionId)
      .maybeSingle();

    if (credentialsError != null) {
      throw new Error("Nao foi possivel carregar as credenciais OAuth.");
    }

    const refreshToken = normalizedText(credentials?.["refresh_token"]);
    if (refreshToken == null) {
      throw new Error(
        "A conta ligada nao tem refresh token disponivel. E necessario voltar a autenticar.",
      );
    }

    let tokenSet: Awaited<ReturnType<typeof refreshProviderAccessToken>>;
    try {
      tokenSet = await refreshProviderAccessToken(provider, refreshToken);
      await persistCredentialRefresh({
        connectionId,
        provider,
        refreshToken,
        tokenSet,
      });
    } catch (error) {
      const message = error instanceof Error
        ? error.message
        : "Falha ao renovar o access token OAuth.";
      await updateConnectionStatus({
        connectionId,
        status: isReauthErrorMessage(message) ? "needs_reauth" : "error",
        lastError: message,
        markSynced: false,
      });
      await logFailureForAllDrafts({
        companyId: context.companyId,
        connectionId,
        createdBy: context.userId,
        plannedFor,
        drafts,
        message,
      });
      return jsonResponse({
        connection_id: connectionId,
        provider,
        sent_count: 0,
        failed_count: drafts.length,
        results: drafts.map((draft) => ({
          asset_id: draft.assetId,
          recipient_email: draft.recipientEmail,
          subject: draft.subject,
          status: "failed",
          provider_message_id: null,
          error_message: message,
        })),
      });
    }

    const replyToEmail = normalizedText(profile?.["authorization_sender_email"]) ??
      normalizedText(connection["email"]);
    const results: AuthorizationEmailSendItemResult[] = [];
    let hasReauthFailure = false;

    for (const draft of drafts) {
      try {
        const sendResult = await sendProviderEmail({
          provider,
          accessToken: tokenSet.accessToken,
          recipientEmail: draft.recipientEmail,
          subject: draft.subject,
          body: draft.body,
          replyToEmail,
        });

        const result: AuthorizationEmailSendItemResult = {
          asset_id: draft.assetId,
          recipient_email: draft.recipientEmail,
          subject: draft.subject,
          status: "sent",
          provider_message_id: sendResult.providerMessageId,
          error_message: null,
        };
        results.push(result);
        await insertDeliveryLog({
          companyId: context.companyId,
          connectionId,
          createdBy: context.userId,
          plannedFor,
          result,
          metadata: sendResult.rawResponse,
        });
      } catch (error) {
        const message = error instanceof Error
          ? error.message
          : "Falha ao enviar o email.";
        if (isReauthErrorMessage(message)) {
          hasReauthFailure = true;
        }

        const result: AuthorizationEmailSendItemResult = {
          asset_id: draft.assetId,
          recipient_email: draft.recipientEmail,
          subject: draft.subject,
          status: "failed",
          provider_message_id: null,
          error_message: message,
        };
        results.push(result);
        await insertDeliveryLog({
          companyId: context.companyId,
          connectionId,
          createdBy: context.userId,
          plannedFor,
          result,
        });
      }
    }

    const sentCount = results.filter((item) => item.status === "sent").length;
    const failedCount = results.length - sentCount;
    const firstFailedResult = results.find((item) => item.status === "failed");
    const lastError = failedCount == 0
      ? null
      : firstFailedResult?.error_message ?? "Falha ao enviar pelo menos um email.";

    await updateConnectionStatus({
      connectionId,
      status: hasReauthFailure ? "needs_reauth" : failedCount > 0 ? "error" : "connected",
      lastError,
      markSynced: sentCount > 0,
    });

    return jsonResponse({
      connection_id: connectionId,
      provider,
      sent_count: sentCount,
      failed_count: failedCount,
      results,
    });
  } catch (error) {
    return jsonResponse(
      {
        error: error instanceof Error
          ? error.message
          : "Falha ao enviar os emails de autorizacao.",
      },
      400,
    );
  }
});
