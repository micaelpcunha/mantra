# Supabase Edge Functions for Email Providers

## Functions

- `account-bootstrap`
  - valida o utilizador autenticado
  - cria uma nova empresa para self-signup
  - associa o perfil atual a essa empresa como `admin`
  - cria/atualiza o `company_profile`

- `email-provider-start`
  - valida o admin autenticado
  - cria o `state` assinado
  - devolve o URL de autorizacao Google ou Microsoft

- `email-provider-callback`
  - valida o `state`
  - troca o `code` por tokens
  - resolve a identidade da conta ligada
  - faz upsert em `company_email_connections`
  - guarda tokens em `company_email_connection_credentials`
  - atualiza `company_profile`

- `authorization-email-send`
  - valida o admin autenticado
  - renova o access token a partir do refresh token guardado
  - envia emails reais pela Gmail API ou Microsoft Graph
  - regista sucesso/erro em `authorization_email_delivery_logs`
  - atualiza o estado da conta ligada quando existe falha ou reautenticacao
    necessaria

- `daily-operations-summary`
  - valida o admin autenticado
  - recolhe ordens com atividade no dia, backlog em aberto e planeamento diario
  - prepara um snapshot estruturado do contexto operacional
  - gera um resumo com OpenAI quando `OPENAI_API_KEY` existe
  - faz fallback para um resumo local quando a chave nao existe ou a chamada falha
  - guarda o resultado em `daily_ai_summaries`

## SQL necessario

Executa estes dois scripts antes de usar as functions:

1. `SUPABASE_EMAIL_PROVIDER_FOUNDATION.sql`
2. `SUPABASE_EMAIL_PROVIDER_BACKEND.sql`

Para o resumo diario, aplica tambem a migration:

3. `supabase/migrations/20260412113000_daily_ai_summaries.sql`

## Secrets / env vars

Obrigatorios:

- `EMAIL_PROVIDER_STATE_SECRET`
- `GOOGLE_OAUTH_CLIENT_ID`
- `GOOGLE_OAUTH_CLIENT_SECRET`
- `MICROSOFT_OAUTH_CLIENT_ID`
- `MICROSOFT_OAUTH_CLIENT_SECRET`

Opcional:

- `EMAIL_PROVIDER_CALLBACK_URL`
  - se vazio, as functions usam automaticamente
    `https://<project-ref>.supabase.co/functions/v1/email-provider-callback`
- `MICROSOFT_OAUTH_TENANT_ID`
  - por defeito usa `common`
- `OPENAI_API_KEY`
  - ativa o resumo com IA; se faltar, a function usa o resumo local
- `OPENAI_DAILY_SUMMARY_MODEL`
  - opcional; por defeito usa `gpt-5-mini`

## Redirect URI a registar nos providers

Usa o callback:

`https://<project-ref>.supabase.co/functions/v1/email-provider-callback`

ou o valor definido em `EMAIL_PROVIDER_CALLBACK_URL`.

## JWT nas functions

Estas cinco functions devem ser publicadas com `verify_jwt = false`:

- `account-bootstrap`
  - a function valida o utilizador dentro do proprio codigo e evita falhas de
    gateway como `Invalid JWT` durante o onboarding de uma nova empresa

- `email-provider-start`
  - a function valida o admin dentro do proprio codigo com o header
    `Authorization`
- `email-provider-callback`
  - o callback precisa de aceitar o redirect publico do Google ou Microsoft
- `authorization-email-send`
  - a function tambem valida o admin dentro do proprio codigo e evita falhas
    do gateway como `Invalid JWT` quando o envio automatico e iniciado pela app
- `daily-operations-summary`
  - a function valida o admin dentro do proprio codigo e evita o mesmo problema
    de gateway quando o resumo e gerado a partir da app

O repositorio ja inclui este detalhe em `supabase/config.toml`, para o deploy
nao voltar a ficar preso em `401 Invalid JWT`.

## Deploy

Deploy recomendado:

```bash
supabase functions deploy account-bootstrap
supabase functions deploy email-provider-start
supabase functions deploy email-provider-callback
supabase functions deploy authorization-email-send
supabase functions deploy daily-operations-summary
```
