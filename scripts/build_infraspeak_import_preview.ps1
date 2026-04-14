[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$InputPath,
  [string]$OutputRoot = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-RepoRoot {
  return (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

function Get-SafeLabel {
  param([string]$Value)

  $safe = ($Value.Trim() -replace '[^A-Za-z0-9_-]+', '_').Trim('_')
  if ([string]::IsNullOrWhiteSpace($safe)) {
    return 'preview'
  }

  return $safe
}

function Normalize-ComparisonValue {
  param([string]$Value)

  if ($null -eq $Value) {
    return ''
  }

  $normalized = $Value.Normalize([System.Text.NormalizationForm]::FormD)
  $builder = New-Object System.Text.StringBuilder

  foreach ($character in $normalized.ToCharArray()) {
    $category = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($character)
    if ($category -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
      [void]$builder.Append($character)
    }
  }

  return $builder.ToString().ToLowerInvariant().Trim()
}

function Normalize-CenterName {
  param([string]$LocationFullName)

  $value = if ($null -ne $LocationFullName) { $LocationFullName.Trim() } else { '' }
  if ([string]::IsNullOrWhiteSpace($value)) {
    return ''
  }

  if ($value -match ':\s*') {
    $value = ($value -split ':\s*', 2)[1].Trim()
  }

  $value = $value -replace '\s+-\s+(Geral|Zona T.+cnica)$', ''
  $value = $value -replace '^[A-Z0-9ª&.]+-', ''

  return $value.Trim()
}

function Get-CenterDisplayName {
  param([string]$NormalizedCenterName)

  $value = if ($null -ne $NormalizedCenterName) { $NormalizedCenterName.Trim() } else { '' }
  $key = $value.ToUpperInvariant()

  switch ($key) {
    'FORUM COIMBRA' { return 'Forum Coimbra' }
    'FORUM AVEIRO' { return 'Forum Aveiro' }
    'FORUM VISEU' { return 'Forum Viseu' }
    'LEIRIASHOPPING' { return 'Leiria Shopping' }
    'ALMA SHOPPING' { return 'Alma Shopping' }
    'SERRA SHOPPING' { return 'Serra Shopping' }
    'HEROIS DE ANGOLA' { return 'Herois de Angola' }
    '8ª AVENIDA' { return '8ª Avenida' }
    default {
      $textInfo = [System.Globalization.CultureInfo]::GetCultureInfo('pt-PT').TextInfo
      return $textInfo.ToTitleCase($value.ToLowerInvariant())
    }
  }
}

function Join-UniqueValues {
  param([System.Collections.IEnumerable]$Values)

  return (
    $Values |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
      ForEach-Object { $_.ToString().Trim() } |
      Where-Object { $_ } |
      Sort-Object -Unique
  ) -join ' | '
}

function Test-XmlProperty {
  param(
    $Node,
    [Parameter(Mandatory = $true)][string]$PropertyName
  )

  if ($null -eq $Node) {
    return $false
  }

  return $Node.PSObject.Properties.Match($PropertyName).Count -gt 0
}

function Get-RichTextValue {
  param($Node)

  if ($null -eq $Node) {
    return ''
  }

  if ((Test-XmlProperty -Node $Node -PropertyName 't') -and $Node.t) {
    return [string]$Node.t
  }

  if ((Test-XmlProperty -Node $Node -PropertyName 'r') -and $Node.r) {
    $parts = foreach ($run in $Node.r) {
      if ((Test-XmlProperty -Node $run -PropertyName 't') -and $run.t -ne $null) {
        [string]$run.t
      }
    }
    return ($parts -join '')
  }

  return ''
}

function Get-ColumnIndex {
  param([string]$CellReference)

  if ([string]::IsNullOrWhiteSpace($CellReference)) {
    return $null
  }

  $letters = ($CellReference -replace '[0-9]', '')
  if ([string]::IsNullOrWhiteSpace($letters)) {
    return $null
  }

  $sum = 0
  foreach ($character in $letters.ToCharArray()) {
    $sum = ($sum * 26) + ([int][char]$character - [int][char]'A' + 1)
  }

  return $sum - 1
}

function Get-CellValue {
  param(
    $Cell,
    [string[]]$SharedStrings
  )

  $cellType = if (Test-XmlProperty -Node $Cell -PropertyName 't') { [string]$Cell.t } else { '' }

  if ($cellType -eq 's') {
    $index = 0
    $rawValue = if (Test-XmlProperty -Node $Cell -PropertyName 'v') { [string]$Cell.v } else { '' }
    if ([int]::TryParse($rawValue, [ref]$index) -and $index -ge 0 -and $index -lt $SharedStrings.Count) {
      return $SharedStrings[$index]
    }
  }

  if ($cellType -eq 'inlineStr') {
    $inlineNode = if (Test-XmlProperty -Node $Cell -PropertyName 'is') { $Cell.is } else { $null }
    return Get-RichTextValue -Node $inlineNode
  }

  if ((Test-XmlProperty -Node $Cell -PropertyName 'v') -and $Cell.v) {
    return [string]$Cell.v
  }

  return ''
}

function Read-EntryText {
  param(
    [Parameter(Mandatory = $true)]$ZipArchive,
    [Parameter(Mandatory = $true)][string]$EntryName
  )

  $entry = $ZipArchive.Entries | Where-Object { $_.FullName -eq $EntryName }
  if (-not $entry) {
    return $null
  }

  $reader = [System.IO.StreamReader]::new($entry.Open())
  try {
    return $reader.ReadToEnd()
  } finally {
    $reader.Dispose()
  }
}

function Open-XlsxWorkbook {
  param([Parameter(Mandatory = $true)][string]$Path)

  $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)

  try {
    $sharedStrings = @()
    $sharedXml = Read-EntryText -ZipArchive $zip -EntryName 'xl/sharedStrings.xml'
    if ($sharedXml) {
      [xml]$sharedDoc = $sharedXml
      if ((Test-XmlProperty -Node $sharedDoc -PropertyName 'sst') -and
          (Test-XmlProperty -Node $sharedDoc.sst -PropertyName 'si')) {
        foreach ($item in $sharedDoc.sst.si) {
          $sharedStrings += (Get-RichTextValue -Node $item)
        }
      }
    }

    [xml]$workbookXml = Read-EntryText -ZipArchive $zip -EntryName 'xl/workbook.xml'
    [xml]$relationsXml = Read-EntryText -ZipArchive $zip -EntryName 'xl/_rels/workbook.xml.rels'

    $relationMap = @{}
    foreach ($relation in $relationsXml.Relationships.Relationship) {
      $relationMap[$relation.Id] = $relation.Target
    }

    $sheets = @{}
    foreach ($sheet in $workbookXml.workbook.sheets.sheet) {
      $sheetName = [string]$sheet.name
      $relationId = $sheet.GetAttribute('id', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')
      $target = $relationMap[$relationId]
      if ([string]::IsNullOrWhiteSpace($target)) {
        continue
      }

      [xml]$sheetXml = Read-EntryText -ZipArchive $zip -EntryName ("xl/$target")
      $rowNodes = @($sheetXml.worksheet.sheetData.row)
      if ($rowNodes.Count -lt 3) {
        $sheets[$sheetName] = @()
        continue
      }

      $headersByIndex = @{}
      foreach ($cell in @($rowNodes[2].c)) {
        $index = Get-ColumnIndex -CellReference $cell.r
        if ($null -eq $index -or $index -lt 0) {
          continue
        }

        $headerValue = Get-CellValue -Cell $cell -SharedStrings $sharedStrings
        if ([string]::IsNullOrWhiteSpace($headerValue)) {
          continue
        }

        $headersByIndex["$index"] = $headerValue
      }

      $rows = @()
      foreach ($rowNode in ($rowNodes | Select-Object -Skip 3)) {
        $rowMap = [ordered]@{}
        foreach ($header in $headersByIndex.Values) {
          $rowMap[$header] = ''
        }

        foreach ($cell in @($rowNode.c)) {
          $index = Get-ColumnIndex -CellReference $cell.r
          if ($null -eq $index -or $index -lt 0) {
            continue
          }

          $indexKey = "$index"
          if (-not $headersByIndex.ContainsKey($indexKey)) {
            continue
          }

          $headerName = $headersByIndex[$indexKey]
          $rowMap[$headerName] = Get-CellValue -Cell $cell -SharedStrings $sharedStrings
        }

        if (-not [string]::IsNullOrWhiteSpace($rowMap['Asset ID'])) {
          $rowMap['_sheet_name'] = $sheetName
          $rows += [pscustomobject]$rowMap
        }
      }

      $sheets[$sheetName] = $rows
    }

    return $sheets
  } finally {
    $zip.Dispose()
  }
}

function Get-RowValue {
  param(
    [Parameter(Mandatory = $true)]$Row,
    [Parameter(Mandatory = $true)][string[]]$CandidateKeys
  )

  $properties = @($Row.PSObject.Properties)
  foreach ($candidateKey in $CandidateKeys) {
    $normalizedCandidate = Normalize-ComparisonValue -Value $candidateKey
    foreach ($property in $properties) {
      if ((Normalize-ComparisonValue -Value $property.Name) -eq $normalizedCandidate) {
        return $(if ($null -ne $property.Value) { [string]$property.Value } else { '' })
      }
    }
  }

  return ''
}

$repoRoot = Get-RepoRoot
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $OutputRoot = Join-Path $repoRoot 'imports\infraspeak'
}

$resolvedInput = (Resolve-Path $InputPath).Path
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$sourceLabel = Get-SafeLabel -Value ([System.IO.Path]::GetFileNameWithoutExtension($resolvedInput))
$outputDirectory = Join-Path $OutputRoot "${timestamp}_${sourceLabel}"
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

$workbook = Open-XlsxWorkbook -Path $resolvedInput
$sheetNames = @($workbook.Keys)

$softRows = foreach ($sheetName in $sheetNames | Where-Object { $_ -like 'INST.*' }) {
  $workbook[$sheetName]
}

$equipmentRows = if ($workbook.ContainsKey('EQUI.QE')) { $workbook['EQUI.QE'] } else { @() }

$locationMap = @{}
$assetMap = @{}
$procedureMap = @{}
$assignmentMap = @{}
$deviceMap = @{}

foreach ($row in $softRows) {
  $locationFullName = (Get-RowValue -Row $row -CandidateKeys @('location full name')).Trim()
  $clientName = (Get-RowValue -Row $row -CandidateKeys @('client')).Trim()
  $assetId = (Get-RowValue -Row $row -CandidateKeys @('asset id')).Trim()
  $locationFullCode = (Get-RowValue -Row $row -CandidateKeys @('location full code')).Trim()
  $nfcId = (Get-RowValue -Row $row -CandidateKeys @('nfc id')).Trim()
  $observations = (Get-RowValue -Row $row -CandidateKeys @('observations')).Trim()
  $assetQrCode = (Get-RowValue -Row $row -CandidateKeys @('qr code')).Trim()
  $procedureName = (Get-RowValue -Row $row -CandidateKeys @('maintenance name')).Trim()
  $sheetName = (Get-RowValue -Row $row -CandidateKeys @('_sheet_name')).Trim()
  $normalizedCenterName = Normalize-CenterName -LocationFullName $locationFullName
  $centerName = Get-CenterDisplayName -NormalizedCenterName $normalizedCenterName

  if ([string]::IsNullOrWhiteSpace($centerName) -or [string]::IsNullOrWhiteSpace($clientName)) {
    continue
  }

  if (-not $locationMap.ContainsKey($centerName)) {
    $locationMap[$centerName] = [ordered]@{
      location_name = $centerName
      source_location_variants = New-Object System.Collections.Generic.List[string]
    }
  }
  $locationMap[$centerName].source_location_variants.Add($locationFullName)

  $assetKey = "$clientName || $normalizedCenterName"
  if (-not $assetMap.ContainsKey($assetKey)) {
    $assetMap[$assetKey] = [ordered]@{
      name = "$clientName $centerName"
      location_name = $centerName
      qr_code = ''
      requires_qr_scan_for_maintenance = $false
      source_client = $clientName
      source_general_location_names = New-Object System.Collections.Generic.List[string]
      source_zone_location_names = New-Object System.Collections.Generic.List[string]
      source_asset_ids = New-Object System.Collections.Generic.List[string]
      source_location_codes = New-Object System.Collections.Generic.List[string]
      source_nfc_ids = New-Object System.Collections.Generic.List[string]
      source_observations = New-Object System.Collections.Generic.List[string]
    }
  }

  $asset = $assetMap[$assetKey]
  $asset.source_asset_ids.Add($assetId)
  $asset.source_location_codes.Add($locationFullCode)
  $asset.source_nfc_ids.Add($nfcId)
  $asset.source_observations.Add($observations)

  if ($locationFullName -match 'Zona T.+cnica') {
    $asset.source_zone_location_names.Add($locationFullName)
  } else {
    $asset.source_general_location_names.Add($locationFullName)
  }

  if ([string]::IsNullOrWhiteSpace($asset.qr_code) -and -not [string]::IsNullOrWhiteSpace($assetQrCode)) {
    $asset.qr_code = $assetQrCode
  }

  if (-not [string]::IsNullOrWhiteSpace($procedureName)) {
    if (-not $procedureMap.ContainsKey($procedureName)) {
      $procedureMap[$procedureName] = [ordered]@{
        template_name = $procedureName
        suggested_order_type = 'preventiva'
        source_sheet_names = New-Object System.Collections.Generic.List[string]
      }
    }

    $procedureMap[$procedureName].source_sheet_names.Add($sheetName)

    $assignmentKey = "$assetKey || $procedureName"
    if (-not $assignmentMap.ContainsKey($assignmentKey)) {
      $assignmentMap[$assignmentKey] = [ordered]@{
        asset_name = $asset.name
        location_name = $centerName
        procedure_name = $procedureName
        suggested_order_title = "$procedureName - $($asset.name)"
        suggested_order_type = 'preventiva'
        source_sheet_name = $sheetName
        source_asset_id = $assetId
      }
    }
  }
}

foreach ($row in $equipmentRows) {
  $locationFullName = (Get-RowValue -Row $row -CandidateKeys @('location full name')).Trim()
  $locationFullCode = (Get-RowValue -Row $row -CandidateKeys @('location full code')).Trim()
  $clientName = (Get-RowValue -Row $row -CandidateKeys @('client')).Trim()
  $deviceName = (Get-RowValue -Row $row -CandidateKeys @('maintenance name')).Trim()
  $equipmentQrCode = (Get-RowValue -Row $row -CandidateKeys @('qr code')).Trim()
  $maintenanceFullCode = (Get-RowValue -Row $row -CandidateKeys @('maintenance full code')).Trim()
  $brand = (Get-RowValue -Row $row -CandidateKeys @('a01. marca')).Trim()
  $model = (Get-RowValue -Row $row -CandidateKeys @('a02. modelo')).Trim()
  $serialNumber = (Get-RowValue -Row $row -CandidateKeys @('a03. numero de serie')).Trim()
  $fabricationYear = (Get-RowValue -Row $row -CandidateKeys @('a04. ano de fabrico')).Trim()
  $observations = (Get-RowValue -Row $row -CandidateKeys @('observations')).Trim()
  $assetId = (Get-RowValue -Row $row -CandidateKeys @('asset id')).Trim()
  $normalizedCenterName = Normalize-CenterName -LocationFullName $locationFullName
  $centerName = Get-CenterDisplayName -NormalizedCenterName $normalizedCenterName

  if ([string]::IsNullOrWhiteSpace($centerName) -or [string]::IsNullOrWhiteSpace($clientName) -or [string]::IsNullOrWhiteSpace($deviceName)) {
    continue
  }

  $assetName = "$clientName $centerName"
  $deviceKey = "$assetName || $deviceName"
  if ($deviceMap.ContainsKey($deviceKey)) {
    continue
  }

  $descriptionParts = @()
  if (-not [string]::IsNullOrWhiteSpace($locationFullName)) {
    $descriptionParts += "Origem: $locationFullName"
  }
  if (-not [string]::IsNullOrWhiteSpace($locationFullCode)) {
    $descriptionParts += "Codigo local: $locationFullCode"
  }
  if (-not [string]::IsNullOrWhiteSpace($brand)) {
    $descriptionParts += "Marca: $brand"
  }
  if (-not [string]::IsNullOrWhiteSpace($model)) {
    $descriptionParts += "Modelo: $model"
  }
  if (-not [string]::IsNullOrWhiteSpace($fabricationYear)) {
    $descriptionParts += "Ano de fabrico: $fabricationYear"
  }
  if (-not [string]::IsNullOrWhiteSpace($observations)) {
    $descriptionParts += "Observacoes: $observations"
  }

  $deviceMap[$deviceKey] = [ordered]@{
    asset_name = $assetName
    location_name = $centerName
    name = $deviceName
    description = ($descriptionParts -join ' | ')
    manufacturer_reference = $serialNumber
    internal_reference = if (-not [string]::IsNullOrWhiteSpace($locationFullCode)) { $locationFullCode } else { $maintenanceFullCode }
    qr_code = $equipmentQrCode
    source_asset_id = $assetId
  }
}

$locations = $locationMap.Values |
  Sort-Object location_name |
  ForEach-Object {
    [pscustomobject]@{
      location_name = $_.location_name
      source_location_variants = Join-UniqueValues -Values $_.source_location_variants
    }
  }

$assets = $assetMap.Values |
  Sort-Object location_name, name |
  ForEach-Object {
    [pscustomobject]@{
      name = $_.name
      location_name = $_.location_name
      qr_code = $_.qr_code
      requires_qr_scan_for_maintenance = $_.requires_qr_scan_for_maintenance
      source_client = $_.source_client
      source_general_location_names = Join-UniqueValues -Values $_.source_general_location_names
      source_zone_location_names = Join-UniqueValues -Values $_.source_zone_location_names
      source_asset_ids = Join-UniqueValues -Values $_.source_asset_ids
      source_location_codes = Join-UniqueValues -Values $_.source_location_codes
      source_nfc_ids = Join-UniqueValues -Values $_.source_nfc_ids
      source_observations = Join-UniqueValues -Values $_.source_observations
    }
  }

$assetDevices = $deviceMap.Values |
  Sort-Object location_name, asset_name, name |
  ForEach-Object { [pscustomobject]$_ }

$procedureTemplates = $procedureMap.Values |
  Sort-Object template_name |
  ForEach-Object {
    [pscustomobject]@{
      template_name = $_.template_name
      suggested_order_type = $_.suggested_order_type
      source_sheet_names = Join-UniqueValues -Values $_.source_sheet_names
    }
  }

$assetProcedureAssignments = $assignmentMap.Values |
  Sort-Object location_name, asset_name, procedure_name |
  ForEach-Object { [pscustomobject]$_ }

$summary = [ordered]@{
  created_at = (Get-Date).ToString('o')
  source_file = $resolvedInput
  output_directory = $outputDirectory
  counts = [ordered]@{
    soft_maintenance_rows = $softRows.Count
    equipment_rows = $equipmentRows.Count
    locations = $locations.Count
    assets = $assets.Count
    asset_devices = $assetDevices.Count
    procedure_templates = $procedureTemplates.Count
    asset_procedure_assignments = $assetProcedureAssignments.Count
  }
}

$locationsPath = Join-Path $outputDirectory 'locations.csv'
$assetsPath = Join-Path $outputDirectory 'assets.csv'
$devicesPath = Join-Path $outputDirectory 'asset_devices.csv'
$proceduresPath = Join-Path $outputDirectory 'procedure_templates.csv'
$assignmentsPath = Join-Path $outputDirectory 'asset_procedure_assignments.csv'
$summaryJsonPath = Join-Path $outputDirectory 'summary.json'
$summaryMdPath = Join-Path $outputDirectory 'summary.md'

$locations | Export-Csv -Path $locationsPath -NoTypeInformation -Encoding UTF8
$assets | Export-Csv -Path $assetsPath -NoTypeInformation -Encoding UTF8
$assetDevices | Export-Csv -Path $devicesPath -NoTypeInformation -Encoding UTF8
$procedureTemplates | Export-Csv -Path $proceduresPath -NoTypeInformation -Encoding UTF8
$assetProcedureAssignments | Export-Csv -Path $assignmentsPath -NoTypeInformation -Encoding UTF8
$summary | ConvertTo-Json -Depth 6 | Set-Content -Path $summaryJsonPath -Encoding UTF8

@(
  '# Infraspeak Import Preview',
  '',
  "Origem: $resolvedInput",
  "Gerado em: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))",
  '',
  '## Contagens',
  "- Localizacoes: $($locations.Count)",
  "- Ativos: $($assets.Count)",
  "- Dispositivos: $($assetDevices.Count)",
  "- Procedimentos: $($procedureTemplates.Count)",
  "- Associacoes ativo/procedimento: $($assetProcedureAssignments.Count)",
  '',
  '## Ficheiros',
  "- $locationsPath",
  "- $assetsPath",
  "- $devicesPath",
  "- $proceduresPath",
  "- $assignmentsPath"
) | Set-Content -Path $summaryMdPath -Encoding UTF8

Write-Host "Preview criada em: $outputDirectory"
