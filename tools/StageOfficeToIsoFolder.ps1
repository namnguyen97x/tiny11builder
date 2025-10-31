param(
    [Parameter(Mandatory=$true)][string]$IsoExtractDir,
    [string]$OfficeMode = 'mock', # mock | download
    [string]$Language = 'en-us',
    [string]$Edition = 'ProPlus2021Volume',
    [string]$Channel = 'PerpetualVL2021'
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

if (-not (Test-Path -LiteralPath $IsoExtractDir)) {
    throw "IsoExtractDir not found: $IsoExtractDir"
}

# Build $OEM$ structure under extracted ISO
$oemRoot      = Join-Path $IsoExtractDir 'sources\$OEM$'
$oemDollar    = Join-Path $oemRoot '$$'
$oemOne       = Join-Path $oemRoot '$1'
$scriptsDir   = Join-Path $oemDollar 'Setup\Scripts'
$officeDir    = Join-Path $oemOne 'OfficeInstall'

New-DirectorySafe $scriptsDir
New-DirectorySafe $officeDir

# Create ODT configuration (LTSC 2021 Pro Plus)
$configXml = Join-Path $officeDir 'configuration.xml'
Set-Content -LiteralPath $configXml -Value @"
<Configuration>
  <Add OfficeClientEdition="64" Channel="$Channel">
    <Product ID="$Edition">
      <Language ID="$Language" />
    </Product>
  </Add>
  <Display Level="None" AcceptEULA="TRUE" />
  <Property Name="AUTOACTIVATE" Value="1" />
</Configuration>
"@

if ($OfficeMode -ieq 'download') {
    # Attempt to fetch ODT and pre-stage payload (large). For CI safety, only download ODT.
    $odtUrl = 'https://download.microsoft.com/download/2/6/5/265B8E0D-DFB9-4F2B-9F0A-FAE21E7638E5/officedeploymenttool_16626-20170.exe'
    $odtExe = Join-Path $officeDir 'odt.exe'
    try {
        Invoke-WebRequest -Uri $odtUrl -OutFile $odtExe -UseBasicParsing
        # Extract ODT contents silently
        Start-Process -FilePath $odtExe -ArgumentList "/quiet /extract:$officeDir" -Wait
        Remove-Item -LiteralPath $odtExe -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Failed to download/extract ODT: $_. Using mock placeholder."
        $OfficeMode = 'mock'
    }
}

if ($OfficeMode -ine 'download') {
    # Create placeholders (no real payload)
    $setupExePath = Join-Path $officeDir 'setup.exe'
    if (-not (Test-Path $setupExePath)) {
        Set-Content -LiteralPath $setupExePath -Value 'Placeholder for setup.exe (ODT)'
    }
    Set-Content -LiteralPath (Join-Path $officeDir 'README.txt') -Value @'
This folder is prepared for Office LTSC 2021 Pro Plus installation via SetupComplete.
Replace placeholders with:
 - setup.exe (Office Deployment Tool)
 - configuration.xml (already provided)
 - Office\ (optional offline payload if needed)
'@
}

# SetupComplete to run silent install on first boot
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

Write-Host "Office staging complete in: $IsoExtractDir"

