[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$BackupPath,
  [switch]$Force
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

function Resolve-BackupDumpPath {
  param([Parameter(Mandatory = $true)][string]$Path)

  $resolved = Resolve-Path $Path -ErrorAction Stop
  $item = Get-Item $resolved
  if ($item.PSIsContainer) {
    $defaultDump = Join-Path $item.FullName 'public_full.dump'
    if (-not (Test-Path $defaultDump)) {
      throw "A pasta $($item.FullName) nao contem public_full.dump."
    }
    return (Resolve-Path $defaultDump).Path
  }

  return $item.FullName
}

function Invoke-PgRestore {
  param(
    [Parameter(Mandatory = $true)][string]$PgRestorePath,
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

    & $PgRestorePath @Arguments
    if ($LASTEXITCODE -ne 0) {
      throw "pg_restore terminou com codigo $LASTEXITCODE."
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
$pgRestorePath = Get-PgBinaryPath -BinaryName 'pg_restore.exe'
$dbEnv = Get-SupabaseDbEnvironment -RepoRoot $repoRoot
$dumpPath = Resolve-BackupDumpPath -Path $BackupPath

if (-not $Force) {
  $confirmation = Read-Host "Isto vai repor o estado do public schema a partir de $dumpPath. Escreve RESTORE para continuar"
  if ($confirmation -ne 'RESTORE') {
    throw 'Restauro cancelado.'
  }
}

Write-Host "A repor backup a partir de $dumpPath"

Invoke-PgRestore -PgRestorePath $pgRestorePath -DbEnv $dbEnv -Arguments @(
  '--clean',
  '--if-exists',
  '--single-transaction',
  '--exit-on-error',
  '--no-owner',
  '--no-privileges',
  '--role=postgres',
  '--schema=public',
  '--dbname=postgres',
  $dumpPath
)

Write-Host 'Restauro concluido.'
