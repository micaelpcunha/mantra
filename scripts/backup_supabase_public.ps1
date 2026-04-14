[CmdletBinding()]
param(
  [string]$BackupLabel = 'pre_infraspeak_test',
  [string]$OutputRoot = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
  return (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

function Get-SafeLabel {
  param([string]$Value)

  $safe = ($Value.Trim() -replace '[^A-Za-z0-9_-]+', '_').Trim('_')
  if ([string]::IsNullOrWhiteSpace($safe)) {
    return 'backup'
  }

  return $safe
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

function Invoke-PgDump {
  param(
    [Parameter(Mandatory = $true)][string]$PgDumpPath,
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

    & $PgDumpPath @Arguments
    if ($LASTEXITCODE -ne 0) {
      throw "pg_dump terminou com codigo $LASTEXITCODE."
    }
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

$repoRoot = Get-RepoRoot
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $OutputRoot = Join-Path $repoRoot 'backups\supabase'
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$safeLabel = Get-SafeLabel -Value $BackupLabel
$backupDirectory = Join-Path $OutputRoot "${timestamp}_${safeLabel}"
New-Item -ItemType Directory -Force -Path $backupDirectory | Out-Null

$pgDumpPath = Get-PgBinaryPath -BinaryName 'pg_dump.exe'
$dbEnv = Get-SupabaseDbEnvironment -RepoRoot $repoRoot

$schemaPath = Join-Path $backupDirectory 'public_schema.sql'
$dataPath = Join-Path $backupDirectory 'public_data.sql'
$customPath = Join-Path $backupDirectory 'public_full.dump'
$manifestPath = Join-Path $backupDirectory 'manifest.json'
$notesPath = Join-Path $backupDirectory 'restore_notes.txt'

Write-Host "A gerar backup do public schema em $backupDirectory"

Invoke-PgDump -PgDumpPath $pgDumpPath -DbEnv $dbEnv -Arguments @(
  '--schema=public',
  '--schema-only',
  '--quote-all-identifiers',
  '--role=postgres',
  '--no-owner',
  '--no-privileges',
  "--file=$schemaPath"
)

Invoke-PgDump -PgDumpPath $pgDumpPath -DbEnv $dbEnv -Arguments @(
  '--schema=public',
  '--data-only',
  '--column-inserts',
  '--quote-all-identifiers',
  '--role=postgres',
  '--no-owner',
  '--no-privileges',
  "--file=$dataPath"
)

Invoke-PgDump -PgDumpPath $pgDumpPath -DbEnv $dbEnv -Arguments @(
  '--schema=public',
  '--format=custom',
  '--quote-all-identifiers',
  '--role=postgres',
  '--no-owner',
  '--no-privileges',
  "--file=$customPath"
)

$projectRefPath = Join-Path $repoRoot 'supabase\.temp\project-ref'
$poolerPath = Join-Path $repoRoot 'supabase\.temp\pooler-url'

$manifest = [ordered]@{
  created_at = (Get-Date).ToString('o')
  backup_label = $BackupLabel
  project_ref = if (Test-Path $projectRefPath) { (Get-Content $projectRefPath -Raw).Trim() } else { $null }
  pooler_url = if (Test-Path $poolerPath) { (Get-Content $poolerPath -Raw).Trim() } else { $null }
  output_directory = $backupDirectory
  files = [ordered]@{
    schema_sql = $schemaPath
    data_sql = $dataPath
    full_dump = $customPath
  }
  tooling = [ordered]@{
    pg_dump = $pgDumpPath
    source = 'supabase db dump --linked --dry-run'
  }
}

$manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $manifestPath -Encoding UTF8

@(
  'Backup criado com sucesso.',
  '',
  "Schema SQL: $schemaPath",
  "Data SQL:   $dataPath",
  "Full dump:  $customPath",
  '',
  'Para reverter este estado mais tarde:',
  "powershell -ExecutionPolicy Bypass -File `"$repoRoot\scripts\restore_supabase_public_backup.ps1`" -BackupPath `"$customPath`""
) | Set-Content -Path $notesPath -Encoding UTF8

Write-Host "Backup concluido: $backupDirectory"
