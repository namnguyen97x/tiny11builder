param(
    [string]$IsoExtractDir,
    [string]$OutputDir,
    [switch]$VerboseLog
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-DirectorySafe {
    param([string]$Path)
    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        if (-not (Test-Path -LiteralPath $Path)) {
            New-Item -ItemType Directory -Path $Path | Out-Null
        }
    }
}

function Write-Log {
    param([string]$Message)
    if ($VerboseLog) { Write-Host $Message }
}

# 1) Prepare workspace (mock if not provided)
if (-not $IsoExtractDir) {
    $IsoExtractDir = Join-Path $env:RUNNER_TEMP 'iso_mock'
    if (-not $env:RUNNER_TEMP) { $IsoExtractDir = Join-Path $env:TEMP 'iso_mock' }
}
if (-not $OutputDir) {
    $OutputDir = Join-Path $env:RUNNER_TEMP 'out_mock'
    if (-not $env:RUNNER_TEMP) { $OutputDir = Join-Path $env:TEMP 'out_mock' }
}

Write-Log "IsoExtractDir: $IsoExtractDir"
Write-Log "OutputDir    : $OutputDir"

New-DirectorySafe $IsoExtractDir
New-DirectorySafe (Join-Path $IsoExtractDir 'sources')
New-DirectorySafe $OutputDir

# 2) Build $OEM$ structure inside extracted ISO folder
$oemRoot      = Join-Path $IsoExtractDir 'sources\$OEM$'
$oemDollar    = Join-Path $oemRoot '$$'
$oemOne       = Join-Path $oemRoot '$1'
$scriptsDir   = Join-Path $oemDollar 'Setup\Scripts'
$officeDir    = Join-Path $oemOne 'OfficeInstall'

New-DirectorySafe $scriptsDir
New-DirectorySafe $officeDir

# 3) Create mock Office payload and config
$setupExePath = Join-Path $officeDir 'setup.exe'
$configXml    = Join-Path $officeDir 'configuration.xml'
$payloadNote  = Join-Path $officeDir 'README.txt'

Set-Content -LiteralPath $payloadNote -Value @'
This is a mock Office payload folder for CI testing.
Replace with actual Office Deployment Tool files:
 - setup.exe
 - configuration.xml
 - Office\ (downloaded payload)
'@

# For CI safety, we do not include a real executable. Create a harmless placeholder.
Set-Content -LiteralPath $setupExePath -Value 'Placeholder for setup.exe (ODT)'
Set-Content -LiteralPath $configXml -Value @'
<Configuration>
  <Add OfficeClientEdition="64" Channel="Current">
    <Product ID="O365ProPlusRetail">
      <Language ID="en-us" />
    </Product>
  </Add>
  <Display Level="None" AcceptEULA="TRUE" />
  <Property Name="AUTOACTIVATE" Value="1" />
</Configuration>
'@

# 4) Create SetupComplete.cmd to trigger silent install (references staged path on target)
$setupComplete = Join-Path $scriptsDir 'SetupComplete.cmd'
Set-Content -LiteralPath $setupComplete -Value @'
@echo off
setlocal
set OFFICE_DIR=C:\OfficeInstall
if exist "%OFFICE_DIR%\setup.exe" (
  "%OFFICE_DIR%\setup.exe" /configure "%OFFICE_DIR%\configuration.xml"
)
exit /b 0
'@ -Encoding ASCII

Write-Log 'OEM structure prepared successfully.'

# 5) Package artifact (zip) for inspection
$artifactZip = Join-Path $OutputDir 'office-oem-staged.zip'
if (Test-Path -LiteralPath $artifactZip) { Remove-Item -LiteralPath $artifactZip -Force }

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($IsoExtractDir, $artifactZip)

Write-Host "Artifact created: $artifactZip"

