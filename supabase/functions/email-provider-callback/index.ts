import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  buildProviderLabel,
  buildReturnUrl,
  createServiceClient,
  exchangeAuthorizationCode,
  fetchProviderIdentity,
  htmlResponse,
  renderCallbackResultHtml,
  upsertCompanyEmailConnection,
  verifyStateToken,
} from "../_shared/email_provider_oauth.ts";

function redirectResponse(location: string) {
  return new Response(null, {
    status: 303,
    headers: {
      Location: location,
      "Cache-Control": "no-store",
    },
  });
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const code = url.searchParams.get("code")?.trim() ?? "";
  const providerError = url.searchParams.get("error")?.trim();
  const errorDescription =
    url.searchParams.get("error_description")?.trim() ??
    url.searchParams.get("error_message")?.trim() ??
    providerError;
  const rawState = url.searchParams.get("state")?.trim() ?? "";

  let state:
    | Awaited<ReturnType<typeof verifyStateToken>>
    | null = null;

  try {
    state = await verifyStateToken(rawState);
  } catch (error) {
    return htmlResponse(
      renderCallbackResultHtml({
        success: false,
        title: "Falha na ligacao da conta",
        message: error instanceof Error
          ? error.message
          : "Nao foi possivel validar o state OAuth.",
      }),
      400,
    );
  }

  if (providerError != null && providerError.length > 0) {
    const redirectUrl = buildReturnUrl(state.returnTo, {
      status: "error",
      provider: state.provider,
      error: errorDescription ?? "Autorizacao recusada.",
    });
    if (redirectUrl != null) {
      return redirectResponse(redirectUrl);
    }

    return htmlResponse(
      renderCallbackResultHtml({
        success: false,
        title: "Autorizacao cancelada",
        message: errorDescription ?? "A ligacao da conta foi cancelada.",
      }),
      400,
    );
  }

  try {
    if (code.length === 0) {
      throw new Error("O provider nao devolveu um authorization code.");
    }

    const serviceClient = createServiceClient();
    const { data: profile, error: profileError } = await serviceClient
      .from("profiles")
      .select("id, role, company_id, email")
      .eq("id", state.userId)
      .maybeSingle();

    if (profileError != null || profile == null) {
      throw new Error("Perfil do administrador nao encontrado.");
    }

    const role = profile["role"]?.toString().trim().toLowerCase() ?? "";
    const companyId = profile["company_id"]?.toString().trim() ?? "";
    if (role != "admin" || companyId != state.companyId) {
      throw new Error(
        "A autorizacao ja nao corresponde a um administrador valido desta empresa.",
      );
    }

    const tokenSet = await exchangeAuthorizationCode(state.provider, code, req);
    const identity = await fetchProviderIdentity(
      state.provider,
      tokenSet.accessToken,
    );
    const result = await upsertCompanyEmailConnection({
      context: {
        userId: state.userId,
        companyId: state.companyId,
        email: profile["email"]?.toString().trim() ?? null,
        role,
      },
      provider: state.provider,
      identity,
      tokenSet,
    });

    const redirectUrl = buildReturnUrl(state.returnTo, {
      status: "success",
      provider: state.provider,
      email: result.email,
      connection_id: result.connectionId,
    });
    if (redirectUrl != null) {
      return redirectResponse(redirectUrl);
    }

    return htmlResponse(
      renderCallbackResultHtml({
        success: true,
        title: "Conta ligada com sucesso",
        message:
          `${buildProviderLabel(state.provider)} ligada para ${result.email}.`,
      }),
    );
  } catch (error) {
    const message = error instanceof Error
      ? error.message
      : "Nao foi possivel concluir a ligacao OAuth.";
    const redirectUrl = buildReturnUrl(state.returnTo, {
      status: "error",
      provider: state.provider,
      error: message,
    });
    if (redirectUrl != null) {
      return redirectResponse(redirectUrl);
    }

    return htmlResponse(
      renderCallbackResultHtml({
        success: false,
        title: "Falha na ligacao da conta",
        message,
      }),
      400,
    );
  }
});
