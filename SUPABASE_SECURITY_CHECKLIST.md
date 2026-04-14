# Supabase Security Checklist

## Objetivo

Este ficheiro resume o endurecimento de seguranca que falta no backend
Supabase para garantir que:

- um tecnico nao consegue alterar dados fora do que lhe foi permitido
- um utilizador com app modificada nao consegue contornar a UI
- clientes apenas veem o ambito atribuido
- anexos e documentos sensiveis nao ficam publicos sem controlo
- cada empresa fica isolada das restantes quando a app evoluir para multiempresa

## Contexto observado no codigo

### Tabelas usadas pela app

- `profiles`
- `technicians`
- `assets`
- `locations`
- `work_orders`
- `company_profile`
- `admin_notifications`

### Buckets usados pela app

- `work-order-photos`
- `work-order-attachments`
- `technician-profile-photos`
- `technician-documents`
- `asset-profile-photos`
- `location-photos`
- `company-media`

### Campos de permissao usados pela app

- `role`
- `technician_id`
- `can_access_assets`
- `can_access_locations`
- `can_access_work_orders`
- `can_create_work_orders`
- `can_view_all_work_orders`
- `can_close_work_orders`
- `can_edit_work_orders`
- `can_edit_assets`
- `can_edit_locations`
- `can_view_alerts`
- `can_manage_technicians`
- `can_manage_users`
- `can_client_view_description`
- `can_client_view_comments`
- `can_client_view_photos`
- `can_client_view_attachments`
- `can_client_view_scheduling`
- `can_client_view_technician`
- `can_client_view_location`
- `client_asset_ids`
- `client_location_ids`

## Principios obrigatorios

1. Nunca confiar na UI para seguranca.
2. Todas as permissoes reais devem ser impostas por RLS e policies.
3. `profiles` deve ser a fonte de verdade das roles e permissoes.
4. O utilizador autenticado so pode ler o proprio `profile`, exceto admins.
5. Tecnicos so podem ver/editar o que as policies permitirem explicitamente.
6. Buckets com documentos sensiveis devem ser privados.
7. Operacoes sensiveis devem ser negadas por omissao.

## Checklist de auditoria imediata

### 1. Confirmar que o RLS esta ativo

Corre isto no SQL Editor do Supabase:

```sql
select schemaname, tablename, rowsecurity
from pg_tables
where schemaname = 'public'
  and tablename in (
    'admin_notifications',
    'asset_devices',
    'assets',
    'companies',
    'company_email_connection_credentials',
    'company_email_connections',
    'company_profile',
    'custom_field_definitions',
    'custom_field_values',
    'locations',
    'memberships',
    'notes',
    'procedure_templates',
    'profiles',
    'technicians',
    'work_order_qr_validations',
    'work_orders'
  )
order by tablename;
```

Objetivo:

- todas estas tabelas devem devolver `rowsecurity = true`

### 2. Listar policies atuais

```sql
select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename in (
    'admin_notifications',
    'asset_devices',
    'assets',
    'companies',
    'company_email_connection_credentials',
    'company_email_connections',
    'company_profile',
    'custom_field_definitions',
    'custom_field_values',
    'locations',
    'memberships',
    'notes',
    'procedure_templates',
    'profiles',
    'technicians',
    'work_order_qr_validations',
    'work_orders'
  )
order by tablename, cmd, policyname;
```

Objetivo:

- perceber quem pode `select`
- perceber quem pode `insert`
- perceber quem pode `update`
- perceber quem pode `delete`
- confirmar se tabelas legacy sem uso atual, como `memberships` e
  `work_order_qr_validations`, continuam pelo menos com `RLS` ativo

### 3. Rever buckets e se sao publicos

```sql
select id, name, public, file_size_limit, allowed_mime_types
from storage.buckets
where id in (
  'work-order-photos',
  'work-order-attachments',
  'technician-profile-photos',
  'technician-documents',
  'asset-profile-photos',
  'location-photos',
  'company-media'
)
order by id;
```

Objetivo:

- `technician-documents` deve ser privado
- `work-order-attachments` deve ser privado
- confirmar se ha outros buckets publicos sem necessidade

## Regras minimas por tabela

### `profiles`

Esperado:

- admin pode ler e gerir todos
- cada utilizador autenticado pode ler apenas o proprio perfil
- tecnico nao pode promover-se a admin
- tecnico nao pode editar flags de permissao
- cliente nao pode editar o proprio ambito

Validar especialmente:

- `update` em `profiles` nao deve estar aberto a qualquer `authenticated`
- `upsert` de perfis deve ficar apenas para admin ou processo controlado

### `technicians`

Esperado:

- admin pode ler/escrever todos
- tecnico normal nao deve listar todos os tecnicos
- tecnico so pode ler o proprio registo tecnico se isso for necessario
- criar, editar e apagar tecnicos deve ser admin apenas

Risco observado no codigo:

- a app faz `select`, `insert`, `update` e `delete` diretamente nesta tabela

### `assets`

Esperado:

- admin pode gerir tudo
- tecnico pode ler ativos apenas se tiver `can_access_assets`
- tecnico so pode editar ativos se tiver `can_edit_assets`
- cliente so pode ver ativos em `client_asset_ids` ou por localizacao autorizada

Validar especialmente:

- `update` e `delete` por tecnico so se permitido
- QR code e campos estruturais nao devem estar abertos a qualquer autenticado

### `locations`

Esperado:

- admin pode gerir tudo
- tecnico so le se tiver `can_access_locations`
- tecnico so edita se tiver `can_edit_locations`
- cliente so ve locais em `client_location_ids` ou associados aos seus ativos

### `work_orders`

Esperado:

- admin pode gerir tudo
- tecnico com `can_view_all_work_orders = true` pode ver tudo
- tecnico normal so deve ver ordens onde `technician_id` = seu tecnico
- tecnico so cria se tiver `can_create_work_orders`
- tecnico so edita se tiver `can_edit_work_orders`
- tecnico so fecha se tiver `can_close_work_orders`
- cliente so ve ordens dentro do seu ambito visivel

Validar especialmente:

- um tecnico nao pode alterar `technician_id` para roubar ordens
- um tecnico nao pode apagar ordens sem permissao explicita
- um cliente nao pode criar nem editar ordens

### `company_profile`

Esperado:

- apenas admin pode ler e editar
- tecnico e cliente nao devem aceder

### `admin_notifications`

Esperado:

- leitura apenas para admin ou tecnicos com `can_view_alerts`
- criacao/edicao idealmente feita por backend controlado
- clientes nao devem aceder

## Buckets: politica recomendada

### Privados

Devem ser privados:

- `technician-documents`
- `work-order-attachments`
- `company-media` se incluir conteudo interno

Recomendado tambem rever se devem ser privados:

- `work-order-photos`
- `technician-profile-photos`
- `asset-profile-photos`
- `location-photos`

### Publicos

So deixar publico se:

- o ficheiro nao for sensivel
- qualquer pessoa autenticada poder ver sem risco
- nao houver dados pessoais ou operacionais sensiveis

### Regra de ouro

Se o bucket for privado:

- usar signed URLs curtas
- criar policy por pasta ou por contexto de ownership

## Perguntas que temos de responder no painel Supabase

1. Quem pode `select/update/delete` em `profiles`?
2. Quem pode listar `technicians`?
3. Quem pode editar `assets` e `locations`?
4. Quem pode atualizar `work_orders.status`?
5. Quem pode alterar `work_orders.technician_id`?
6. Os clientes estao realmente limitados por `client_asset_ids` e `client_location_ids` no backend?
7. Que buckets estao publicos hoje?
8. Os documentos tecnicos podem ser descarregados sem signed URL?

## Resultado esperado apos hardening

Mesmo que um tecnico:

- altere o APK
- intercepte requests
- use o anon key diretamente
- tente chamar o Supabase fora da app

deve continuar sem conseguir:

- promover-se
- editar perfis
- criar ou editar tecnicos
- ver ordens fora do seu ambito
- editar ativos ou locais sem permissao
- descarregar documentos privados sem autorizacao

## Proximo passo

Abrir o painel Supabase e correr as queries deste ficheiro.
Depois comparamos o resultado com esta checklist e fechamos as policies uma a uma.

## Migracao Multiempresa

### Ordem recomendada

1. Fazer backup da base de dados antes de qualquer migracao estrutural.
2. Aplicar `SUPABASE_PRODUCT_FOUNDATION.sql`.
3. Correr `SUPABASE_MULTITENANT_VALIDATION.sql`.
4. Confirmar que nao existem registos operacionais com `company_id` a `null`.
5. Aplicar `SUPABASE_MULTITENANT_RLS.sql`.
6. Repetir `SUPABASE_MULTITENANT_VALIDATION.sql`.
7. Validar a app com contas admin, tecnico e cliente.

### Resultado esperado apos `SUPABASE_PRODUCT_FOUNDATION.sql`

- existe a tabela `companies`
- existe pelo menos uma empresa base para os dados legacy
- as tabelas principais passam a ter coluna `company_id`
- os dados atuais ficam preenchidos com `company_id`
- existem triggers para auto-preencher `company_id` em novos inserts
- existem as tabelas:
  - `custom_field_definitions`
  - `custom_field_values`

### Resultado esperado apos `SUPABASE_MULTITENANT_RLS.sql`

- um utilizador de uma empresa nao consegue ver dados de outra
- admins continuam a gerir os dados da propria empresa
- tecnicos continuam limitados por role e flags, mas agora tambem por empresa
- clientes continuam limitados por ambito e por empresa
- `admin_notifications` continuam a funcionar quando tecnicos editam ou fecham ordens

## Matriz de Testes Manuais

### Admin

Validar que um admin autenticado consegue:

- entrar na app sem erro
- listar e editar `assets`
- listar e editar `locations`
- listar e editar `technicians`
- listar e editar `profiles`
- criar e editar `work_orders`
- abrir `company_profile`

### Tecnico

Validar que um tecnico autenticado:

- so ve os dados da propria empresa
- nao consegue listar todos os utilizadores
- nao consegue editar `profiles`
- nao consegue criar ou editar `technicians` sem permissao
- so ve ou edita `work_orders` conforme flags e regras atuais
- consegue continuar a gerar `admin_notifications` ao fechar ou editar ordens

### Cliente

Validar que um cliente autenticado:

- so ve dados da propria empresa
- so ve `assets`, `locations` e `work_orders` dentro do ambito atribuido
- nao consegue criar nem editar ordens
- nao acede a `company_profile`
- nao acede a `technicians`

### Storage

Confirmar novamente:

- `work-order-attachments` continua privado
- `technician-documents` continua privado
- signed URLs continuam a abrir anexos e documentos legitimos
- nenhum bucket sensivel ficou publico por acidente durante a migracao
