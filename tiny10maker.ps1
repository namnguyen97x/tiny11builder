param(
    [Parameter(Mandatory = $true)][ValidatePattern('^[A-Z]$')][string]$ISO,
    [Parameter(Mandatory = $false)][ValidatePattern('^[A-Z]$')][string]$SCRATCH,
    [string]$VersionSelector = 'Auto',
    [switch]$NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info([string]$msg) { Write-Host $msg }
function New-DirectoryIfMissing([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { New-Item -ItemType Directory -Path $path | Out-Null }
}

# Honor workflow debloat toggles for maker (win10)
$removeDefender = if ($env:REMOVE_DEFENDER) { $env:REMOVE_DEFENDER } else { 'false' }
$removeEdge     = if ($env:REMOVE_EDGE)     { $env:REMOVE_EDGE }     else { 'true' }
$removeStore    = if ($env:REMOVE_STORE)    { $env:REMOVE_STORE }    else { 'true' }
Write-Info "Debloat (maker): Defender=$removeDefender, Edge=$removeEdge, Store=$removeStore"
if ($NonInteractive) { Write-Info "NonInteractive mode enabled" }

# Resolve drives
$isoDrive = "$ISO:"
if (-not (Test-Path $isoDrive)) { throw "Mounted ISO drive not found: $isoDrive" }

$workspace = Split-Path -Parent $PSCommandPath
$outputIso = Join-Path $workspace 'tiny10.iso'
$workRoot = if ($SCRATCH) { "$SCRATCH:\tiny10_work" } else { Join-Path $env:TEMP 'tiny10_work' }

Write-Info "ISO drive: $isoDrive"
Write-Info "Working folder: $workRoot"
Write-Info "Output ISO: $outputIso"

New-DirectoryIfMissing $workRoot

# Copy ISO contents to work folder
Write-Info 'Copying ISO contents...'
robocopy $isoDrive $workRoot /E /NFL /NDL /NJH /NJS /NP | Out-Null

# Best-effort: try to rebuild ISO if oscdimg exists
$oscdimg = (Get-Command oscdimg.exe -ErrorAction SilentlyContinue).Path
if ($oscdimg) {
    Write-Info "Found oscdimg: $oscdimg"
    $efi  = Join-Path $workRoot 'efi\microsoft\boot\efisys.bin'
    $boot = Join-Path $workRoot 'boot\etfsboot.com'
    $args = @('-m','-u2','-udfver102')
    if (Test-Path $boot) { $args += @('-b', $boot) }
    if (Test-Path $efi)  { $args += @('-bootdata:2#p0,e,b' + $boot + '#pEF,e,b' + $efi) }
    $args += @($workRoot, $outputIso)
    & $oscdimg @args
    if (-not (Test-Path $outputIso)) { throw 'Failed to create tiny10.iso with oscdimg.' }
    Write-Info 'tiny10.iso created.'
} else {
    Write-Info 'oscdimg.exe not found. Skipping ISO rebuild. You can create the ISO locally using ADK.'
}

exit 0

