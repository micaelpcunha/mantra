[CmdletBinding()]
param(
  [switch]$Draft,
  [switch]$SkipBuild,
  [switch]$SkipDeploy
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$localConfig = Join-Path $PSScriptRoot 'netlify.local.ps1'
if (Test-Path $localConfig) {
  . $localConfig
}

$flutterBin = $env:FLUTTER_BIN
if ([string]::IsNullOrWhiteSpace($flutterBin)) {
  $flutterBin = 'C:\Users\pinta\develop\flutter\bin\flutter.bat'
}

$npmCache = $env:npm_config_cache
if ([string]::IsNullOrWhiteSpace($npmCache)) {
  $npmCache = Join-Path $repoRoot '.netlify\npm-cache'
  $env:npm_config_cache = $npmCache
}
New-Item -ItemType Directory -Path $npmCache -Force | Out-Null

if (-not $SkipBuild) {
  if (-not (Test-Path $flutterBin)) {
    throw "Nao foi encontrado o Flutter em '$flutterBin'. Define a variavel FLUTTER_BIN ou ajusta o caminho no script."
  }
}

$buildDir = Join-Path $repoRoot 'build\web'

Push-Location $repoRoot
try {
  if (-not $SkipBuild) {
    Write-Host 'A gerar build web...' -ForegroundColor Cyan
    & $flutterBin build web
    if ($LASTEXITCODE -ne 0) {
      exit $LASTEXITCODE
    }
  }

  if (-not (Test-Path $buildDir)) {
    throw "A pasta '$buildDir' nao existe. Corre primeiro a build web."
  }

  if ($SkipDeploy) {
    Write-Host "Build pronta em '$buildDir'." -ForegroundColor Green
    return
  }

  if ([string]::IsNullOrWhiteSpace($env:NETLIFY_AUTH_TOKEN)) {
    throw 'Falta NETLIFY_AUTH_TOKEN. Define a variavel de ambiente ou cria scripts/netlify.local.ps1 a partir do exemplo.'
  }

  if ([string]::IsNullOrWhiteSpace($env:NETLIFY_SITE_ID)) {
    throw 'Falta NETLIFY_SITE_ID. Define a variavel de ambiente ou cria scripts/netlify.local.ps1 a partir do exemplo.'
  }

  $deployArgs = @(
    '--yes'
    'netlify-cli@latest'
    'deploy'
    '--dir'
    'build/web'
    '--site'
    $env:NETLIFY_SITE_ID
    '--auth'
    $env:NETLIFY_AUTH_TOKEN
  )

  if (-not $Draft) {
    $deployArgs += '--prod'
  }

  Write-Host 'A publicar na Netlify...' -ForegroundColor Cyan
  & npx.cmd @deployArgs
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }

  if ($Draft) {
    Write-Host 'Deploy draft concluido.' -ForegroundColor Green
  } else {
    Write-Host 'Deploy de producao concluido.' -ForegroundColor Green
  }
} finally {
  Pop-Location
}
