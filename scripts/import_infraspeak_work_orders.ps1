[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$PreviewDirectory,
  [string]$CompanyId = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
  return (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

function Get-PgBinaryPath {
  param([Parameter(Mandatory = $true)][string]$BinaryName)

  $command = Get-Command $BinaryName -ErrorAction SilentlyContinue
  if ($command -and $command.Source) {
    return $command.Source
  }

  $searchRoots = @(
    'C:\Program Files\PostgreSQL',
    'C:\Program Files (x86)\PostgreSQL',
    'C:\Users\pinta\AppData\Local\Programs'
  )

  $candidates = foreach ($root in $searchRoots) {
    if (Test-Path $root) {
      Get-ChildItem -Path $root -Filter $BinaryName -Recurse -ErrorAction SilentlyContinue
    }
  }

  $selected = $candidates |
    Sort-Object @{ Expression = { $_.FullName -match '\\bin\\' }; Descending = $true }, FullName -Descending |
    Select-Object -First 1

  if (-not $selected) {
    throw "Nao foi possivel encontrar $BinaryName nesta maquina."
  }

  return $selected.FullName
}

function Get-SupabaseDbEnvironment {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $npmCache = Join-Path $RepoRoot '.npm-cache'
  $previousCache = $env:npm_config_cache
  $env:npm_config_cache = $npmCache

  try {
    $output = & cmd.exe /c "npx.cmd supabase db dump --linked --dry-run 2>&1"
    if ($LASTEXITCODE -ne 0) {
      throw "Falha ao obter as credenciais temporarias do Supabase CLI.`n$output"
    }
  } finally {
    $env:npm_config_cache = $previousCache
  }

  $values = @{}
  foreach ($line in $output) {
    if ($line -match '^export (PGHOST|PGPORT|PGUSER|PGPASSWORD|PGDATABASE)="(.*)"$') {
      $values[$matches[1]] = $matches[2]
    }
  }

  foreach ($requiredKey in @('PGHOST', 'PGPORT', 'PGUSER', 'PGPASSWORD', 'PGDATABASE')) {
    if (-not $values.ContainsKey($requiredKey) -or [string]::IsNullOrWhiteSpace($values[$requiredKey])) {
      throw "Nao foi possivel extrair $requiredKey do dry-run do Supabase CLI."
    }
  }

  return $values
}

function Invoke-Psql {
  param(
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][hashtable]$DbEnv,
    [Parameter(Mandatory = $true)][string[]]$Arguments
  )

  $previous = @{
    PGHOST = $env:PGHOST
    PGPORT = $env:PGPORT
    PGUSER = $env:PGUSER
    PGPASSWORD = $env:PGPASSWORD
    PGDATABASE = $env:PGDATABASE
  }

  try {
    foreach ($entry in $DbEnv.GetEnumerator()) {
      Set-Item -Path "Env:$($entry.Key)" -Value $entry.Value
    }

    $output = & $PsqlPath @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
      throw "psql terminou com codigo $LASTEXITCODE.`n$output"
    }

    return $output
  } finally {
    foreach ($entry in $previous.GetEnumerator()) {
      if ($null -eq $entry.Value) {
        Remove-Item -Path "Env:$($entry.Key)" -ErrorAction SilentlyContinue
      } else {
        Set-Item -Path "Env:$($entry.Key)" -Value $entry.Value
      }
    }
  }
}

function Resolve-PreviewDirectory {
  param([Parameter(Mandatory = $true)][string]$Path)

  $resolved = Resolve-Path $Path -ErrorAction Stop
  $item = Get-Item $resolved
  if (-not $item.PSIsContainer) {
    throw "O caminho $Path nao e uma pasta de preview."
  }

  return $item.FullName
}

function Resolve-PreviewFile {
  param(
    [Parameter(Mandatory = $true)][string]$Directory,
    [Parameter(Mandatory = $true)][string]$FileName
  )

  $path = Join-Path $Directory $FileName
  if (-not (Test-Path $path)) {
    throw "Nao foi encontrado o ficheiro obrigatorio $path."
  }

  return $path
}

function Test-ValidGuid {
  param([string]$Value)

  $parsed = [guid]::Empty
  return [guid]::TryParse($Value, [ref]$parsed)
}

function Convert-CsvToBase64Json {
  param([Parameter(Mandatory = $true)][string]$Path)

  $rows = @(Import-Csv $Path)
  $json = $rows | ConvertTo-Json -Depth 12 -Compress
  if ($null -eq $json) {
    $json = '[]'
  }

  return [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes([string]$json))
}

$repoRoot = Get-RepoRoot
$resolvedPreviewDirectory = Resolve-PreviewDirectory -Path $PreviewDirectory

if (-not [string]::IsNullOrWhiteSpace($CompanyId) -and -not (Test-ValidGuid -Value $CompanyId)) {
  throw 'Se indicada, a CompanyId tem de ser um UUID valido.'
}

$assignmentsPath = Resolve-PreviewFile -Directory $resolvedPreviewDirectory -FileName 'asset_procedure_assignments.csv'
$assignmentsBase64 = Convert-CsvToBase64Json -Path $assignmentsPath

$requestedCompanySql = if ([string]::IsNullOrWhiteSpace($CompanyId)) {
  'null::uuid'
} else {
  "'$($CompanyId.Trim())'::uuid"
}

$importSqlPath = Join-Path $resolvedPreviewDirectory 'import_work_orders_to_supabase.sql'
$importResultPath = Join-Path $resolvedPreviewDirectory 'import_work_orders_result.txt'
$importManifestPath = Join-Path $resolvedPreviewDirectory 'import_work_orders_result.json'

$importSql = @"
\set ON_ERROR_STOP on
begin;
set local role postgres;

create or replace function pg_temp.normalize_import_text(value text)
returns text
language sql
immutable
as __DQ__
  select trim(
    regexp_replace(
      translate(
        lower(coalesce(value, '')),
        U&'\00E1\00E0\00E3\00E2\00E9\00E8\00EA\00ED\00EC\00EE\00F3\00F2\00F5\00F4\00FA\00F9\00FB\00E7\00AA\00BA',
        'aaaaeeeiiioooouuucao'
      ),
      '[^a-z0-9]+',
      ' ',
      'g'
    )
  );
__DQ__;

create temp table import_context on commit drop as
select
  $requestedCompanySql as requested_company_id,
  case
    when $requestedCompanySql is not null then $requestedCompanySql
    when (select count(*) from public.companies) = 1 then (
      select id
      from public.companies
      order by id
      limit 1
    )
    else null::uuid
  end as company_id,
  (select count(*) from public.companies) as company_count;

do __DQ__
declare
  v_requested uuid;
  v_company uuid;
  v_company_count integer;
begin
  select requested_company_id, company_id, company_count
  into v_requested, v_company, v_company_count
  from import_context
  limit 1;

  if v_requested is not null then
    perform 1
    from public.companies
    where id = v_requested;

    if not found then
      raise exception 'A company_id indicada nao existe.';
    end if;
  end if;

  if v_company is null then
    if v_company_count = 0 then
      raise exception 'Nao existem empresas no projeto remoto.';
    end if;

    raise exception 'Existem % empresas no projeto remoto. Indica -CompanyId explicitamente para continuar.', v_company_count;
  end if;
end
__DQ__;

create temp table import_summary (
  metric text primary key,
  value integer not null
) on commit drop;

create or replace function pg_temp.jsonb_array_count(value jsonb)
returns integer
language sql
immutable
as __DQ__
  select case
    when value is null then 0
    when jsonb_typeof(value) = 'array' then jsonb_array_length(value)
    else 0
  end;
__DQ__;

create temp table import_assignments_raw on commit drop as
select
  nullif(trim(coalesce(asset_name, '')), '') as asset_name,
  nullif(trim(coalesce(location_name, '')), '') as location_name,
  nullif(trim(coalesce(procedure_name, '')), '') as procedure_name,
  nullif(trim(coalesce(suggested_order_title, '')), '') as suggested_order_title,
  lower(nullif(trim(coalesce(suggested_order_type, '')), '')) as suggested_order_type,
  nullif(trim(coalesce(source_sheet_name, '')), '') as source_sheet_name,
  nullif(trim(coalesce(source_asset_id, '')), '') as source_asset_id,
  pg_temp.normalize_import_text(asset_name) as normalized_asset_name,
  pg_temp.normalize_import_text(procedure_name) as normalized_procedure_name
from jsonb_to_recordset(
  convert_from(decode('$assignmentsBase64', 'base64'), 'UTF8')::jsonb
) as source_rows(
  asset_name text,
  location_name text,
  procedure_name text,
  suggested_order_title text,
  suggested_order_type text,
  source_sheet_name text,
  source_asset_id text
)
where nullif(trim(coalesce(asset_name, '')), '') is not null
  and nullif(trim(coalesce(procedure_name, '')), '') is not null
  and nullif(trim(coalesce(suggested_order_title, '')), '') is not null;

alter table import_assignments_raw
  add column asset_id uuid,
  add column procedure_template_id uuid,
  add column procedure_steps jsonb,
  add column generated_reference text,
  add column description_text text,
  add column comment_text text;

update import_assignments_raw source
set asset_id = target.id
from public.assets target
where target.company_id = (select company_id from import_context)
  and pg_temp.normalize_import_text(target.name) = source.normalized_asset_name;

do __DQ__
begin
  if exists (
    select 1
    from import_assignments_raw
    where asset_id is null
  ) then
    raise exception 'Existem ordens do preview sem ativo resolvido.';
  end if;
end
__DQ__;

update import_assignments_raw source
set
  procedure_template_id = target.id,
  procedure_steps = coalesce(target.steps, '[]'::jsonb)
from public.procedure_templates target
where target.company_id = (select company_id from import_context)
  and pg_temp.normalize_import_text(target.name) = source.normalized_procedure_name;

update import_assignments_raw
set
  generated_reference = left(
    'IFS-PREV-' ||
    coalesce(source_asset_id, 'SEM-ASSET') || '-' ||
    regexp_replace(
      upper(coalesce(source_sheet_name, procedure_name)),
      '[^A-Z0-9]+',
      '-',
      'g'
    ),
    120
  ),
  description_text =
    'Importado do Infraspeak. Procedimento: ' || procedure_name || '.' ||
    ' Localizacao: ' || coalesce(location_name, 'Sem localizacao') || '.' ||
    ' Folha origem: ' || coalesce(source_sheet_name, 'desconhecida') || '.' ||
    ' Asset ID origem: ' || coalesce(source_asset_id, 'desconhecido') || '.',
  comment_text =
    'Importado automaticamente do Infraspeak.'
where generated_reference is null;

with updated_rows as (
  update public.work_orders target
  set
    title = source.suggested_order_title,
    description = coalesce(nullif(trim(coalesce(target.description, '')), ''), source.description_text),
    comment = coalesce(nullif(trim(coalesce(target.comment, '')), ''), source.comment_text),
    priority = coalesce(nullif(trim(coalesce(target.priority, '')), ''), 'normal'),
    order_type = case
      when nullif(trim(coalesce(target.order_type, '')), '') is null then coalesce(source.suggested_order_type, 'preventiva')
      else target.order_type
    end,
    procedure_template_id = coalesce(target.procedure_template_id, source.procedure_template_id),
    procedure_name = coalesce(nullif(trim(coalesce(target.procedure_name, '')), ''), source.procedure_name),
    procedure_steps = case
      when pg_temp.jsonb_array_count(target.procedure_steps) = 0
        and pg_temp.jsonb_array_count(source.procedure_steps) > 0
      then coalesce(source.procedure_steps, '[]'::jsonb)
      else target.procedure_steps
    end,
    updated_at = timezone('utc', now())
  from import_assignments_raw source
  where target.company_id = (select company_id from import_context)
    and target.reference = source.generated_reference
    and (
      target.title is distinct from source.suggested_order_title
      or nullif(trim(coalesce(target.description, '')), '') is null
      or nullif(trim(coalesce(target.comment, '')), '') is null
      or nullif(trim(coalesce(target.order_type, '')), '') is null
      or target.procedure_template_id is null
      or nullif(trim(coalesce(target.procedure_name, '')), '') is null
      or (
        pg_temp.jsonb_array_count(target.procedure_steps) = 0
        and pg_temp.jsonb_array_count(source.procedure_steps) > 0
      )
      or nullif(trim(coalesce(target.priority, '')), '') is null
    )
  returning 1
)
insert into import_summary(metric, value)
select 'work_orders_updated', count(*)::integer
from updated_rows;

with inserted_rows as (
  insert into public.work_orders (
    company_id,
    asset_id,
    title,
    reference,
    description,
    status,
    priority,
    comment,
    order_type,
    procedure_template_id,
    procedure_name,
    procedure_steps,
    created_at,
    updated_at
  )
  select
    context.company_id,
    source.asset_id,
    source.suggested_order_title,
    source.generated_reference,
    source.description_text,
    'pendente',
    'normal',
    source.comment_text,
    coalesce(source.suggested_order_type, 'preventiva'),
    source.procedure_template_id,
    source.procedure_name,
    coalesce(source.procedure_steps, '[]'::jsonb),
    timezone('utc', now()),
    timezone('utc', now())
  from import_assignments_raw source
  cross join import_context context
  where not exists (
    select 1
    from public.work_orders existing
    where existing.company_id = context.company_id
      and existing.reference = source.generated_reference
  )
  returning 1
)
insert into import_summary(metric, value)
select 'work_orders_inserted', count(*)::integer
from inserted_rows;

insert into import_summary(metric, value)
select 'work_orders_total', count(*)::integer
from public.work_orders
where company_id = (select company_id from import_context);

insert into import_summary(metric, value)
select 'preventive_work_orders_total', count(*)::integer
from public.work_orders
where company_id = (select company_id from import_context)
  and order_type = 'preventiva';

select 'company' as section, 'company_id' as metric, company_id::text as detail
from import_context
union all
select 'summary' as section, metric, value::text as detail
from import_summary
order by section, metric;

commit;
"@

$importSql = $importSql.Replace('__DQ__', '$$')
$importSql | Set-Content -Path $importSqlPath -Encoding UTF8

$psqlPath = Get-PgBinaryPath -BinaryName 'psql.exe'
$dbEnv = Get-SupabaseDbEnvironment -RepoRoot $repoRoot

$psqlOutput = Invoke-Psql -PsqlPath $psqlPath -DbEnv $dbEnv -Arguments @(
  '-X',
  '-A',
  '-F',
  '|',
  '-P',
  'pager=off',
  '-f',
  $importSqlPath
)

$psqlOutput | Set-Content -Path $importResultPath -Encoding UTF8

$manifest = [ordered]@{
  executed_at = (Get-Date).ToString('o')
  preview_directory = $resolvedPreviewDirectory
  company_id = if ([string]::IsNullOrWhiteSpace($CompanyId)) { $null } else { $CompanyId.Trim() }
  sql_file = $importSqlPath
  result_file = $importResultPath
}

$manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $importManifestPath -Encoding UTF8

Write-Host "Importacao das ordens concluida com sucesso. Resultados: $importResultPath"
