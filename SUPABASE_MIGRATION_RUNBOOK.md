# Supabase Migration Runbook

Guiao curto para aplicar a migracao multiempresa no Supabase sem improviso.

## Antes de comecar

Faz isto primeiro:

1. Usa o projeto de desenvolvimento, nao o de producao.
2. Garante backup antes de mexer no schema.
3. Fecha sessoes da app que estejam a escrever dados durante a migracao.

## Ordem exata

### Passo 1. Aplicar a fundacao multiempresa

No SQL Editor do Supabase:

1. Cria uma query nova.
2. Cola o conteudo de [SUPABASE_PRODUCT_FOUNDATION.sql](/c:/Users/pinta/asset_app/SUPABASE_PRODUCT_FOUNDATION.sql).
3. Executa.

Se correr bem, deves ficar com:

- tabela `companies`
- coluna `company_id` nas tabelas principais
- dados legacy preenchidos com `company_id`
- triggers para auto-preencher `company_id`
- tabelas `custom_field_definitions` e `custom_field_values`

Se aparecer erro:

- para aqui
- nao avances para o passo 2
- copia o erro e manda-mo

### Passo 2. Validar a fundacao

No SQL Editor:

1. Cria uma query nova.
2. Cola o conteudo de [SUPABASE_MULTITENANT_VALIDATION.sql](/c:/Users/pinta/asset_app/SUPABASE_MULTITENANT_VALIDATION.sql).
3. Executa.

Confirma especialmente:

- todas as tabelas esperadas existem
- `company_id` existe nas tabelas operacionais
- `missing_company_id` fica a `0` em tudo
- existem triggers `set_*_company_id`

Se algo falhar:

- para aqui
- nao avances para o passo 3
- manda-me o resultado que saiu errado

### Passo 3. Aplicar RLS multiempresa

No SQL Editor:

1. Cria uma query nova.
2. Cola o conteudo de [SUPABASE_MULTITENANT_RLS.sql](/c:/Users/pinta/asset_app/SUPABASE_MULTITENANT_RLS.sql).
3. Executa.

Isto deve deixar as policies a validar:

- isolamento por `company_id`
- restricoes por role
- restricoes por flags de permissao
- limite de clientes por ambito

Se aparecer erro:

- para aqui
- nao sigas para testes funcionais
- copia o erro e manda-mo

### Passo 4. Validar outra vez

Volta a correr [SUPABASE_MULTITENANT_VALIDATION.sql](/c:/Users/pinta/asset_app/SUPABASE_MULTITENANT_VALIDATION.sql).

Confirma especialmente:

- as policies existem nas tabelas principais
- continua sem registos com `company_id` a `null`
- os buckets sensiveis continuam privados

## Smoke test na app

Depois da SQL, testa na app com estas contas:

### Admin

- entra sem erro
- abre `Ativos`
- abre `Localizacoes`
- abre `Ordens`
- abre `Utilizadores`
- abre `Empresa`
- cria ou edita um registo simples

### Tecnico

- entra sem erro
- ve apenas o que ja devia ver
- nao ganha acesso a `Utilizadores`
- continua a conseguir atualizar ordens permitidas

### Cliente

- entra sem erro
- so ve o ambito esperado
- nao consegue editar dados operacionais

## O que me mandar de volta

Se tudo correr bem, manda-me:

1. `foundation aplicada`
2. `validation 1 ok`
3. `rls aplicado`
4. `validation 2 ok`
5. qualquer erro funcional que tenhas visto na app

Se algo correr mal, manda-me:

1. em que passo falhou
2. o erro exato do SQL Editor
3. qual foi a ultima query que executaste
