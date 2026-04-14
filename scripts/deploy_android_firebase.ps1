[CmdletBinding()]
param(
  [ValidateSet('release', 'debug')]
  [string]$BuildType = 'release',
  [string]$BuildName,
  [int]$BuildNumber,
  [string]$Notes,
  [string]$NotesFile,
  [string]$Testers,
  [string]$Groups,
  [string]$ArtifactPath,
  [switch]$SkipBuild,
  [switch]$SkipDistribute
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$localConfig = Join-Path $PSScriptRoot 'firebase_app_distribution.local.ps1'
if (Test-Path $localConfig) {
  . $localConfig
}

$flutterBin = $env:FLUTTER_BIN
if ([string]::IsNullOrWhiteSpace($flutterBin)) {
  $flutterBin = 'C:\Users\pinta\develop\flutter\bin\flutter.bat'
}

$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
$env:ANDROID_SDK_ROOT = "$env:LOCALAPPDATA\Android\Sdk"

$npmCache = $env:npm_config_cache
if ([string]::IsNullOrWhiteSpace($npmCache)) {
  $npmCache = Join-Path $repoRoot '.firebase\npm-cache'
  $env:npm_config_cache = $npmCache
}
New-Item -ItemType Directory -Path $npmCache -Force | Out-Null

if (-not $SkipBuild -and -not (Test-Path $flutterBin)) {
  throw "Nao foi encontrado o Flutter em '$flutterBin'. Define FLUTTER_BIN ou ajusta o caminho no script."
}

function Resolve-ArtifactPath {
  param(
    [string]$RepoRoot,
    [string]$BuildType,
    [string]$ProvidedPath
  )

  if (-not [string]::IsNullOrWhiteSpace($ProvidedPath)) {
    return $ProvidedPath
  }

  if ($BuildType -eq 'debug') {
    return (Join-Path $RepoRoot 'build\app\outputs\flutter-apk\app-debug.apk')
  }

  return (Join-Path $RepoRoot 'build\app\outputs\flutter-apk\app-release.apk')
}

function Get-PubspecVersionInfo {
  param(
    [string]$RepoRoot
  )

  $pubspecPath = Join-Path $RepoRoot 'pubspec.yaml'
  if (-not (Test-Path $pubspecPath)) {
    throw "Nao foi encontrado o pubspec.yaml em '$pubspecPath'."
  }

  $versionLine = Get-Content -Path $pubspecPath |
    Where-Object { $_ -match '^\s*version:\s*(.+?)\s*$' } |
    Select-Object -First 1

  if ([string]::IsNullOrWhiteSpace($versionLine)) {
    throw 'Nao foi possivel encontrar a linha `version:` no pubspec.yaml.'
  }

  $rawVersion = $versionLine -replace '^\s*version:\s*', ''
  $rawVersion = $rawVersion.Trim()

  if ($rawVersion -match '^(.+)\+(\d+)$') {
    return @{
      BuildName = $matches[1].Trim()
      BuildNumber = [int]$matches[2]
      Raw = $rawVersion
    }
  }

  return @{
    BuildName = $rawVersion
    BuildNumber = 1
    Raw = $rawVersion
  }
}

function Resolve-BuildNumberStatePath {
  param(
    [string]$RepoRoot,
    [string]$BuildType
  )

  $stateDir = Join-Path $RepoRoot '.firebase'
  return (Join-Path $stateDir "android-build-number-$BuildType.txt")
}

function Read-LastBuildNumber {
  param(
    [string]$StatePath
  )

  if (-not (Test-Path $StatePath)) {
    return 0
  }

  $rawValue = (Get-Content -Path $StatePath -Raw).Trim()
  $parsedValue = 0
  if ([int]::TryParse($rawValue, [ref]$parsedValue)) {
    return $parsedValue
  }

  return 0
}

function New-AutoBuildNumber {
  param(
    [int]$MinimumBuildNumber,
    [string]$StatePath
  )

  $nowUtc = (Get-Date).ToUniversalTime()
  $timestampText = '{0:yy}{1:D3}{0:HHmm}' -f $nowUtc, $nowUtc.DayOfYear
  $timestampNumber = [int]$timestampText
  $lastBuildNumber = Read-LastBuildNumber -StatePath $StatePath

  $candidate = [Math]::Max($timestampNumber, $MinimumBuildNumber)
  if ($candidate -le $lastBuildNumber) {
    $candidate = $lastBuildNumber + 1
  }

  return $candidate
}

function New-DefaultReleaseNotesFile {
  param(
    [string]$RepoRoot,
    [string]$BuildType,
    [string]$BuildName,
    [int]$BuildNumber
  )

  $notesDir = Join-Path $RepoRoot 'build\firebase'
  New-Item -ItemType Directory -Path $notesDir -Force | Out-Null
  $notesPath = Join-Path $notesDir "release-notes-$BuildType.txt"
  $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
  $content = @(
    "Build Android $BuildType"
    "Versao $BuildName ($BuildNumber)"
    "Gerado em $timestamp"
  )
  Set-Content -Path $notesPath -Value $content -Encoding UTF8
  return $notesPath
}

function Save-BuildNumberState {
  param(
    [string]$StatePath,
    [int]$BuildNumber
  )

  $stateDir = Split-Path -Parent $StatePath
  New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
  Set-Content -Path $StatePath -Value $BuildNumber -Encoding ASCII
}

$resolvedArtifactPath = Resolve-ArtifactPath `
  -RepoRoot $repoRoot `
  -BuildType $BuildType `
  -ProvidedPath $ArtifactPath

$pubspecVersion = Get-PubspecVersionInfo -RepoRoot $repoRoot
$resolvedBuildName = if ([string]::IsNullOrWhiteSpace($BuildName)) {
  $pubspecVersion.BuildName
} else {
  $BuildName.Trim()
}

$buildNumberStatePath = Resolve-BuildNumberStatePath `
  -RepoRoot $repoRoot `
  -BuildType $BuildType

$lastKnownBuildNumber = Read-LastBuildNumber -StatePath $buildNumberStatePath

$resolvedBuildNumber = $null
if ($PSBoundParameters.ContainsKey('BuildNumber')) {
  $resolvedBuildNumber = $BuildNumber
} elseif ($SkipBuild) {
  if ($lastKnownBuildNumber -gt 0) {
    $resolvedBuildNumber = $lastKnownBuildNumber
  } else {
    $resolvedBuildNumber = $pubspecVersion.BuildNumber
  }
} else {
  $resolvedBuildNumber = New-AutoBuildNumber `
    -MinimumBuildNumber $pubspecVersion.BuildNumber `
    -StatePath $buildNumberStatePath
}

$resolvedNotesFile = $NotesFile
if ([string]::IsNullOrWhiteSpace($resolvedNotesFile) -and [string]::IsNullOrWhiteSpace($Notes)) {
  $resolvedNotesFile = New-DefaultReleaseNotesFile `
    -RepoRoot $repoRoot `
    -BuildType $BuildType `
    -BuildName $resolvedBuildName `
    -BuildNumber $resolvedBuildNumber
}

$resolvedTesters = if ([string]::IsNullOrWhiteSpace($Testers)) { $env:FIREBASE_TESTERS } else { $Testers }
$resolvedGroups = if ([string]::IsNullOrWhiteSpace($Groups)) { $env:FIREBASE_GROUPS } else { $Groups }

Push-Location $repoRoot
try {
  if (-not $SkipBuild) {
    Write-Host "A gerar build Android ($BuildType)..." -ForegroundColor Cyan
    Write-Host "Versao Android: $resolvedBuildName ($resolvedBuildNumber)" -ForegroundColor DarkCyan
    if ($BuildType -eq 'debug') {
      & $flutterBin build apk --debug --build-name $resolvedBuildName --build-number $resolvedBuildNumber
    } else {
      & $flutterBin build apk --release --build-name $resolvedBuildName --build-number $resolvedBuildNumber
    }

    if ($LASTEXITCODE -ne 0) {
      exit $LASTEXITCODE
    }

    Save-BuildNumberState -StatePath $buildNumberStatePath -BuildNumber $resolvedBuildNumber
  }

  if (-not (Test-Path $resolvedArtifactPath)) {
    throw "Nao foi encontrado o artefacto Android em '$resolvedArtifactPath'."
  }

  if ($SkipDistribute) {
    Write-Host "APK pronta em '$resolvedArtifactPath'." -ForegroundColor Green
    return
  }

  if ([string]::IsNullOrWhiteSpace($env:FIREBASE_APP_ID)) {
    throw 'Falta FIREBASE_APP_ID. Regista a app Android no Firebase e define este valor no ficheiro local.'
  }

  if ([string]::IsNullOrWhiteSpace($resolvedTesters) -and [string]::IsNullOrWhiteSpace($resolvedGroups)) {
    throw 'Indica pelo menos testers ou groups para distribuir a build.'
  }

  $firebaseArgs = @(
    '--yes'
    'firebase-tools@latest'
    'appdistribution:distribute'
    $resolvedArtifactPath
    '--app'
    $env:FIREBASE_APP_ID
  )

  if (-not [string]::IsNullOrWhiteSpace($env:FIREBASE_TOKEN)) {
    $firebaseArgs += @('--token', $env:FIREBASE_TOKEN)
  }

  if (-not [string]::IsNullOrWhiteSpace($Notes)) {
    $firebaseArgs += @('--release-notes', $Notes)
  } elseif (-not [string]::IsNullOrWhiteSpace($resolvedNotesFile)) {
    $firebaseArgs += @('--release-notes-file', $resolvedNotesFile)
  }

  if (-not [string]::IsNullOrWhiteSpace($resolvedTesters)) {
    $firebaseArgs += @('--testers', $resolvedTesters)
  }

  if (-not [string]::IsNullOrWhiteSpace($resolvedGroups)) {
    $firebaseArgs += @('--groups', $resolvedGroups)
  }

  if (-not [string]::IsNullOrWhiteSpace($env:GOOGLE_APPLICATION_CREDENTIALS)) {
    Write-Host 'Autenticacao Firebase: conta de servico via GOOGLE_APPLICATION_CREDENTIALS.' -ForegroundColor DarkCyan
  } elseif (-not [string]::IsNullOrWhiteSpace($env:FIREBASE_TOKEN)) {
    Write-Host 'Autenticacao Firebase: token FIREBASE_TOKEN.' -ForegroundColor DarkCyan
  } else {
    Write-Host 'Autenticacao Firebase: sessao local do Firebase CLI.' -ForegroundColor DarkCyan
  }

  Write-Host 'A distribuir build no Firebase App Distribution...' -ForegroundColor Cyan
  & npx.cmd @firebaseArgs
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }

  Write-Host 'Distribuicao Firebase concluida.' -ForegroundColor Green
} finally {
  Pop-Location
}
