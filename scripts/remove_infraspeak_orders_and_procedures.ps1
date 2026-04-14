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

$proceduresPath = Resolve-PreviewFile -Directory $resolvedPreviewDirectory -FileName 'procedure_templates.csv'
$proceduresBase64 = Convert-CsvToBase64Json -Path $proceduresPath

$requestedCompanySql = if ([string]::IsNullOrWhiteSpace($CompanyId)) {
  'null::uuid'
} else {
  "'$($CompanyId.Trim())'::uuid"
}

$cleanupSqlPath = Join-Path $resolvedPreviewDirectory 'remove_infraspeak_orders_and_procedures.sql'
$cleanupResultPath = Join-Path $resolvedPreviewDirectory 'remove_infraspeak_orders_and_procedures_result.txt'
$cleanupManifestPath = Join-Path $resolvedPreviewDirectory 'remove_infraspeak_orders_and_procedures_result.json'

$cleanupSql = @"
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

create temp table cleanup_context on commit drop as
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
  from cleanup_context
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

create temp table cleanup_summary (
  metric text primary key,
  value integer not null
) on commit drop;

create temp table imported_procedures_raw on commit drop as
select
  nullif(trim(coalesce(template_name, '')), '') as template_name,
  pg_temp.normalize_import_text(template_name) as normalized_name
from jsonb_to_recordset(
  convert_from(decode('$proceduresBase64', 'base64'), 'UTF8')::jsonb
) as source_rows(
  template_name text,
  suggested_order_type text,
  source_sheet_names text
)
where nullif(trim(coalesce(template_name, '')), '') is not null;

with deleted_work_orders as (
  delete from public.work_orders target
  using cleanup_context context
  where target.company_id = context.company_id
    and target.reference like 'IFS-PREV-%'
  returning 1
)
insert into cleanup_summary(metric, value)
select 'work_orders_deleted', count(*)::integer
from deleted_work_orders;

with deleted_procedures as (
  delete from public.procedure_templates target
  using cleanup_context context
  where target.company_id = context.company_id
    and target.description like 'Importado do Infraspeak (origem:%'
    and exists (
      select 1
      from imported_procedures_raw source
      where source.normalized_name = pg_temp.normalize_import_text(target.name)
    )
  returning 1
)
insert into cleanup_summary(metric, value)
select 'procedure_templates_deleted', count(*)::integer
from deleted_procedures;

insert into cleanup_summary(metric, value)
select 'work_orders_total', count(*)::integer
from public.work_orders
where company_id = (select company_id from cleanup_context);

insert into cleanup_summary(metric, value)
select 'procedure_templates_total', count(*)::integer
from public.procedure_templates
where company_id = (select company_id from cleanup_context);

insert into cleanup_summary(metric, value)
select 'locations_total', count(*)::integer
from public.locations
where company_id = (select company_id from cleanup_context);

insert into cleanup_summary(metric, value)
select 'assets_total', count(*)::integer
from public.assets
where company_id = (select company_id from cleanup_context);

insert into cleanup_summary(metric, value)
select 'asset_devices_total', count(*)::integer
from public.asset_devices
where company_id = (select company_id from cleanup_context);

select 'company' as section, 'company_id' as metric, company_id::text as detail
from cleanup_context
union all
select 'summary' as section, metric, value::text as detail
from cleanup_summary
order by section, metric;

commit;
"@

$cleanupSql = $cleanupSql.Replace('__DQ__', '$$')
$cleanupSql | Set-Content -Path $cleanupSqlPath -Encoding UTF8

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
  $cleanupSqlPath
)

$psqlOutput | Set-Content -Path $cleanupResultPath -Encoding UTF8

$manifest = [ordered]@{
  executed_at = (Get-Date).ToString('o')
  preview_directory = $resolvedPreviewDirectory
  company_id = if ([string]::IsNullOrWhiteSpace($CompanyId)) { $null } else { $CompanyId.Trim() }
  sql_file = $cleanupSqlPath
  result_file = $cleanupResultPath
}

$manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $cleanupManifestPath -Encoding UTF8

Write-Host "Remocao das ordens e procedimentos Infraspeak concluida com sucesso. Resultados: $cleanupResultPath"
