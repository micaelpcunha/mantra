# Email Provider OAuth Setup

## Objetivo

Ligar a configuracao de email da empresa a contas reais de `Google / Gmail` e
`Microsoft / Hotmail / Outlook`, mantendo:

- autenticacao por `OAuth`
- tokens guardados no backend
- envio feito por backend/Edge Function
- selecao da conta ligada em `company_settings_page.dart`

## Base ja preparada no projeto

- `SUPABASE_EMAIL_PROVIDER_FOUNDATION.sql`
  - adiciona `authorization_email_provider` e
    `authorization_email_connection_id` a `company_profile`
  - cria `company_email_connections`
- `SUPABASE_EMAIL_PROVIDER_BACKEND.sql`
  - cria `company_email_connection_credentials`
  - deixa os refresh tokens fora do alcance normal da app
- `lib/company_settings_page.dart`
  - permite escolher `manual`, `google` ou `microsoft`
  - mostra contas ligadas disponiveis e o estado de cada uma
  - inicia a autenticacao OAuth pelo browser
  - permite refrescar a lista de contas ligadas
- `lib/calendar_page.dart`
  - inclui fornecedor, conta ligada e nota de readiness nos rascunhos
- `supabase/functions/email-provider-start/index.ts`
  - arranca o consent flow com `state` assinado
- `supabase/functions/email-provider-callback/index.ts`
  - conclui o callback, guarda a conta e atualiza `company_profile`
- `supabase/config.toml`
  - publica `email-provider-start` e `email-provider-callback` com
    `verify_jwt = false`
- `supabase/functions/README.md`
  - resume env vars e deploy

## Proximo passo tecnico

### Google / Gmail

1. Criar um projeto e credenciais OAuth no Google Cloud.
2. Ativar a Gmail API.
3. Redirecionar o admin para um endpoint backend de inicio de autorizacao.
4. Trocar o `authorization code` por `access token` e `refresh token` no
   backend.
5. Guardar a conta autenticada em `company_email_connections`.
6. Enviar emails pelo backend com Gmail API `messages.send`.

Campos minimos a guardar por conta:

- `provider = 'google'`
- `email`
- `display_name`
- `status`
- `external_account_id`
- `access_scope`
- `connected_at`
- `last_sync_at`
- `last_error`

Links oficiais:

- Google OAuth 2.0 web server apps:
  `https://developers.google.com/identity/protocols/oauth2/web-server`
- Gmail API sending:
  `https://developers.google.com/gmail/api/guides/sending`

### Microsoft / Hotmail / Outlook

1. Criar uma app registration no Microsoft Entra ID.
2. Configurar redirect URI para o callback backend.
3. Pedir permissao delegada `Mail.Send` e `offline_access`.
4. Trocar o `authorization code` por tokens no backend.
5. Guardar a conta autenticada em `company_email_connections`.
6. Enviar emails pelo backend com Microsoft Graph `POST /me/sendMail`.

Links oficiais:

- Microsoft identity / auth concepts:
  `https://learn.microsoft.com/en-us/graph/auth/auth-concepts`
- Microsoft Graph `user: sendMail`:
  `https://learn.microsoft.com/en-us/graph/api/user-sendmail?view=graph-rest-1.0`

## Recomendacao de implementacao no Supabase

### Edge Functions

- `email-provider-start`
  - recebe `provider`
  - valida empresa atual
  - gera `state`
  - redireciona para o consent screen

- `email-provider-callback`
  - valida `state`
  - troca `code` por tokens
  - resolve email e nome da conta
  - faz upsert em `company_email_connections`
  - guarda credenciais em `company_email_connection_credentials`
  - atualiza `company_profile.authorization_email_connection_id`

- `send-authorization-email`
  - recebe `company_id`, `to`, `subject`, `body`
  - carrega a conta ligada da empresa
  - renova token se necessario
  - envia pela API certa
  - atualiza `last_test_at` / `last_sync_at` / `last_error`

## Regras importantes

- nunca guardar client secrets nem refresh tokens na app Flutter
- nunca enviar diretamente para Google/Microsoft a partir do cliente
- preferir sempre uma conta ligada por empresa e fornecedor
- manter `manual` como fallback quando nao houver conta autenticada
- manter `verify_jwt = false` nas functions OAuth
  - `email-provider-start` valida auth dentro da propria function
  - `email-provider-callback` precisa de aceitar o redirect publico do provider

## Proximo passo depois deste scaffold

1. Executar `SUPABASE_EMAIL_PROVIDER_BACKEND.sql`
2. Definir os env vars das functions
3. Fazer deploy de `email-provider-start` e `email-provider-callback`
4. Testar a ligacao Google e Microsoft na app
5. Ligar o envio real backend aos emails de autorizacao
