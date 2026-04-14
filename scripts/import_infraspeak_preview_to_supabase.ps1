[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$PreviewDirectory,
  [string]$CompanyId = '',
  [switch]$SkipDevices,
  [switch]$SkipProcedures
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

function Convert-EmptyJsonToBase64 {
  return [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes('[]'))
}

$repoRoot = Get-RepoRoot
$resolvedPreviewDirectory = Resolve-PreviewDirectory -Path $PreviewDirectory

if (-not [string]::IsNullOrWhiteSpace($CompanyId) -and -not (Test-ValidGuid -Value $CompanyId)) {
  throw 'Se indicada, a CompanyId tem de ser um UUID valido.'
}

$locationsPath = Resolve-PreviewFile -Directory $resolvedPreviewDirectory -FileName 'locations.csv'
$assetsPath = Resolve-PreviewFile -Directory $resolvedPreviewDirectory -FileName 'assets.csv'
$devicesPath = Resolve-PreviewFile -Directory $resolvedPreviewDirectory -FileName 'asset_devices.csv'
$proceduresPath = Resolve-PreviewFile -Directory $resolvedPreviewDirectory -FileName 'procedure_templates.csv'

$locationsBase64 = Convert-CsvToBase64Json -Path $locationsPath
$assetsBase64 = Convert-CsvToBase64Json -Path $assetsPath
$devicesBase64 = if ($SkipDevices) { Convert-EmptyJsonToBase64 } else { Convert-CsvToBase64Json -Path $devicesPath }
$proceduresBase64 = if ($SkipProcedures) { Convert-EmptyJsonToBase64 } else { Convert-CsvToBase64Json -Path $proceduresPath }

$requestedCompanySql = if ([string]::IsNullOrWhiteSpace($CompanyId)) {
  'null::uuid'
} else {
  "'$($CompanyId.Trim())'::uuid"
}

$importSqlPath = Join-Path $resolvedPreviewDirectory 'import_to_supabase.sql'
$importResultPath = Join-Path $resolvedPreviewDirectory 'import_result.txt'
$importManifestPath = Join-Path $resolvedPreviewDirectory 'import_result.json'

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

create temp table import_locations_raw on commit drop as
select
  nullif(trim(coalesce(location_name, '')), '') as location_name,
  nullif(trim(coalesce(source_location_variants, '')), '') as source_location_variants,
  pg_temp.normalize_import_text(location_name) as normalized_name
from jsonb_to_recordset(
  convert_from(decode('$locationsBase64', 'base64'), 'UTF8')::jsonb
) as source_rows(
  location_name text,
  source_location_variants text
)
where nullif(trim(coalesce(location_name, '')), '') is not null;

with updated_rows as (
  update public.locations target
  set name = source.location_name
  from import_locations_raw source
  where target.company_id = (select company_id from import_context)
    and pg_temp.normalize_import_text(target.name) = source.normalized_name
    and target.name is distinct from source.location_name
  returning 1
)
insert into import_summary(metric, value)
select 'locations_updated', count(*)::integer
from updated_rows;

with inserted_rows as (
  insert into public.locations (company_id, name)
  select
    context.company_id,
    source.location_name
  from import_locations_raw source
  cross join import_context context
  where not exists (
    select 1
    from public.locations existing
    where existing.company_id = context.company_id
      and pg_temp.normalize_import_text(existing.name) = source.normalized_name
  )
  returning 1
)
insert into import_summary(metric, value)
select 'locations_inserted', count(*)::integer
from inserted_rows;

create temp table import_location_match on commit drop as
select distinct on (source.normalized_name)
  source.location_name,
  source.normalized_name,
  target.id as location_id
from import_locations_raw source
join public.locations target
  on target.company_id = (select company_id from import_context)
 and pg_temp.normalize_import_text(target.name) = source.normalized_name
order by source.normalized_name, target.id;

create temp table import_assets_raw on commit drop as
select
  nullif(trim(coalesce(name, '')), '') as asset_name,
  nullif(trim(coalesce(location_name, '')), '') as location_name,
  nullif(trim(coalesce(qr_code, '')), '') as qr_code,
  case
    when lower(trim(coalesce(requires_qr_scan_for_maintenance, ''))) = 'true' then true
    else false
  end as requires_qr_scan_for_maintenance,
  nullif(trim(coalesce(source_client, '')), '') as source_client,
  pg_temp.normalize_import_text(name) as normalized_name,
  pg_temp.normalize_import_text(location_name) as normalized_location_name,
  pg_temp.normalize_import_text(source_client) as normalized_client,
  case
    when pg_temp.normalize_import_text(source_client) = 'pull bear' then pg_temp.normalize_import_text('Pull ' || coalesce(location_name, ''))
    else null
  end as alias_normalized_name
from jsonb_to_recordset(
  convert_from(decode('$assetsBase64', 'base64'), 'UTF8')::jsonb
) as source_rows(
  name text,
  location_name text,
  qr_code text,
  requires_qr_scan_for_maintenance text,
  source_client text,
  source_general_location_names text,
  source_zone_location_names text,
  source_asset_ids text,
  source_location_codes text,
  source_nfc_ids text,
  source_observations text
)
where nullif(trim(coalesce(name, '')), '') is not null
  and nullif(trim(coalesce(location_name, '')), '') is not null;

alter table import_assets_raw
  add column location_id uuid;

update import_assets_raw source
set location_id = match.location_id
from import_location_match match
where match.normalized_name = source.normalized_location_name;

do __DQ__
begin
  if exists (
    select 1
    from import_assets_raw
    where location_id is null
  ) then
    raise exception 'Existem ativos sem localizacao resolvida no preview.';
  end if;
end
__DQ__;

create temp table import_asset_candidates on commit drop as
select
  source.*,
  exact_match.asset_id as exact_asset_id,
  alias_match.asset_id as alias_asset_id,
  coalesce(exact_match.asset_id, alias_match.asset_id) as resolved_existing_asset_id
from import_assets_raw source
left join lateral (
  select target.id as asset_id
  from public.assets target
  where target.company_id = (select company_id from import_context)
    and pg_temp.normalize_import_text(target.name) = source.normalized_name
  order by
    case when target.location_id is not distinct from source.location_id then 0 else 1 end,
    target.created_at nulls last,
    target.id
  limit 1
) exact_match on true
left join lateral (
  select target.id as asset_id
  from public.assets target
  where exact_match.asset_id is null
    and source.alias_normalized_name is not null
    and target.company_id = (select company_id from import_context)
    and pg_temp.normalize_import_text(target.name) = source.alias_normalized_name
    and (target.location_id is null or target.location_id is not distinct from source.location_id)
  order by
    case when target.location_id is not distinct from source.location_id then 0 else 1 end,
    target.created_at nulls last,
    target.id
  limit 1
) alias_match on true;

with updated_rows as (
  update public.assets target
  set
    name = source.asset_name,
    location_id = coalesce(source.location_id, target.location_id),
    qr_code = case
      when nullif(trim(coalesce(target.qr_code, '')), '') is null then source.qr_code
      else target.qr_code
    end
  from import_asset_candidates source
  where target.id = source.resolved_existing_asset_id
    and (
      target.name is distinct from source.asset_name
      or target.location_id is distinct from source.location_id
      or (
        nullif(trim(coalesce(target.qr_code, '')), '') is null
        and source.qr_code is not null
      )
    )
  returning 1
)
insert into import_summary(metric, value)
select 'assets_updated', count(*)::integer
from updated_rows;

with inserted_rows as (
  insert into public.assets (
    company_id,
    name,
    status,
    tarefas_concluidas,
    location_id,
    qr_code,
    requires_qr_scan_for_maintenance
  )
  select
    context.company_id,
    source.asset_name,
    'operacional',
    0,
    source.location_id,
    source.qr_code,
    source.requires_qr_scan_for_maintenance
  from import_asset_candidates source
  cross join import_context context
  where source.resolved_existing_asset_id is null
  returning 1
)
insert into import_summary(metric, value)
select 'assets_inserted', count(*)::integer
from inserted_rows;

create temp table import_asset_match on commit drop as
select distinct on (source.normalized_name)
  source.asset_name,
  source.location_name,
  source.normalized_name,
  source.location_id,
  target.id as asset_id
from import_assets_raw source
join public.assets target
  on target.company_id = (select company_id from import_context)
 and pg_temp.normalize_import_text(target.name) = source.normalized_name
order by
  source.normalized_name,
  case when target.location_id is not distinct from source.location_id then 0 else 1 end,
  target.created_at nulls last,
  target.id;

do __DQ__
begin
  if exists (
    select 1
    from import_assets_raw source
    where not exists (
      select 1
      from import_asset_match match
      where match.normalized_name = source.normalized_name
    )
  ) then
    raise exception 'Existem ativos do preview sem correspondencia final apos o merge.';
  end if;
end
__DQ__;

create temp table import_devices_raw on commit drop as
select
  nullif(trim(coalesce(asset_name, '')), '') as asset_name,
  nullif(trim(coalesce(location_name, '')), '') as location_name,
  nullif(trim(coalesce(name, '')), '') as device_name,
  nullif(trim(coalesce(description, '')), '') as description,
  nullif(trim(coalesce(manufacturer_reference, '')), '') as manufacturer_reference,
  nullif(trim(coalesce(internal_reference, '')), '') as internal_reference,
  nullif(trim(coalesce(qr_code, '')), '') as qr_code,
  pg_temp.normalize_import_text(asset_name) as normalized_asset_name,
  pg_temp.normalize_import_text(name) as normalized_device_name
from jsonb_to_recordset(
  convert_from(decode('$devicesBase64', 'base64'), 'UTF8')::jsonb
) as source_rows(
  asset_name text,
  location_name text,
  name text,
  description text,
  manufacturer_reference text,
  internal_reference text,
  qr_code text,
  source_asset_id text
)
where nullif(trim(coalesce(asset_name, '')), '') is not null
  and nullif(trim(coalesce(name, '')), '') is not null;

alter table import_devices_raw
  add column asset_id uuid;

update import_devices_raw source
set asset_id = match.asset_id
from import_asset_match match
where match.normalized_name = source.normalized_asset_name;

do __DQ__
begin
  if exists (
    select 1
    from import_devices_raw
    where asset_id is null
  ) then
    raise exception 'Existem dispositivos do preview sem ativo resolvido.';
  end if;
end
__DQ__;

with updated_rows as (
  update public.asset_devices target
  set
    description = case
      when nullif(trim(coalesce(target.description, '')), '') is null then source.description
      else target.description
    end,
    manufacturer_reference = case
      when nullif(trim(coalesce(target.manufacturer_reference, '')), '') is null then source.manufacturer_reference
      else target.manufacturer_reference
    end,
    internal_reference = case
      when nullif(trim(coalesce(target.internal_reference, '')), '') is null then source.internal_reference
      else target.internal_reference
    end,
    qr_code = case
      when nullif(trim(coalesce(target.qr_code, '')), '') is null then source.qr_code
      else target.qr_code
    end,
    updated_at = timezone('utc', now())
  from import_devices_raw source
  where target.company_id = (select company_id from import_context)
    and target.asset_id = source.asset_id
    and pg_temp.normalize_import_text(target.name) = source.normalized_device_name
    and (
      (nullif(trim(coalesce(target.description, '')), '') is null and source.description is not null)
      or (nullif(trim(coalesce(target.manufacturer_reference, '')), '') is null and source.manufacturer_reference is not null)
      or (nullif(trim(coalesce(target.internal_reference, '')), '') is null and source.internal_reference is not null)
      or (nullif(trim(coalesce(target.qr_code, '')), '') is null and source.qr_code is not null)
    )
  returning 1
)
insert into import_summary(metric, value)
select 'asset_devices_updated', count(*)::integer
from updated_rows;

with inserted_rows as (
  insert into public.asset_devices (
    company_id,
    asset_id,
    name,
    description,
    manufacturer_reference,
    internal_reference,
    qr_code
  )
  select
    context.company_id,
    source.asset_id,
    source.device_name,
    source.description,
    source.manufacturer_reference,
    source.internal_reference,
    source.qr_code
  from import_devices_raw source
  cross join import_context context
  where not exists (
    select 1
    from public.asset_devices existing
    where existing.company_id = context.company_id
      and existing.asset_id = source.asset_id
      and pg_temp.normalize_import_text(existing.name) = source.normalized_device_name
  )
  returning 1
)
insert into import_summary(metric, value)
select 'asset_devices_inserted', count(*)::integer
from inserted_rows;

create temp table import_procedures_raw on commit drop as
select
  nullif(trim(coalesce(template_name, '')), '') as template_name,
  nullif(trim(coalesce(suggested_order_type, '')), '') as suggested_order_type,
  nullif(trim(coalesce(source_sheet_names, '')), '') as source_sheet_names,
  pg_temp.normalize_import_text(template_name) as normalized_name
from jsonb_to_recordset(
  convert_from(decode('$proceduresBase64', 'base64'), 'UTF8')::jsonb
) as source_rows(
  template_name text,
  suggested_order_type text,
  source_sheet_names text
)
where nullif(trim(coalesce(template_name, '')), '') is not null;

with updated_rows as (
  update public.procedure_templates target
  set
    description = coalesce(
      nullif(trim(coalesce(target.description, '')), ''),
      'Importado do Infraspeak (origem: ' || coalesce(source.source_sheet_names, 'desconhecida') || ').'
    ),
    updated_at = timezone('utc', now())
  from import_procedures_raw source
  where target.company_id = (select company_id from import_context)
    and pg_temp.normalize_import_text(target.name) = source.normalized_name
    and nullif(trim(coalesce(target.description, '')), '') is null
  returning 1
)
insert into import_summary(metric, value)
select 'procedure_templates_updated', count(*)::integer
from updated_rows;

with inserted_rows as (
  insert into public.procedure_templates (
    company_id,
    name,
    description,
    steps,
    is_active
  )
  select
    context.company_id,
    source.template_name,
    'Importado do Infraspeak (origem: ' || coalesce(source.source_sheet_names, 'desconhecida') || ').',
    '[]'::jsonb,
    true
  from import_procedures_raw source
  cross join import_context context
  where not exists (
    select 1
    from public.procedure_templates existing
    where existing.company_id = context.company_id
      and pg_temp.normalize_import_text(existing.name) = source.normalized_name
  )
  returning 1
)
insert into import_summary(metric, value)
select 'procedure_templates_inserted', count(*)::integer
from inserted_rows;

insert into import_summary(metric, value)
select 'locations_total', count(*)::integer
from public.locations
where company_id = (select company_id from import_context);

insert into import_summary(metric, value)
select 'assets_total', count(*)::integer
from public.assets
where company_id = (select company_id from import_context);

insert into import_summary(metric, value)
select 'asset_devices_total', count(*)::integer
from public.asset_devices
where company_id = (select company_id from import_context);

insert into import_summary(metric, value)
select 'procedure_templates_total', count(*)::integer
from public.procedure_templates
where company_id = (select company_id from import_context);

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
  applied_devices = -not $SkipDevices
  applied_procedures = -not $SkipProcedures
  sql_file = $importSqlPath
  result_file = $importResultPath
}

$manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $importManifestPath -Encoding UTF8

Write-Host "Importacao concluida com sucesso. Resultados: $importResultPath"
