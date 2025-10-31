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

# Enforce workflow policy: nano profile ignores debloat toggles
$envRemoveDefender = if ($env:REMOVE_DEFENDER) { $env:REMOVE_DEFENDER } else { 'false' }
$envRemoveEdge = if ($env:REMOVE_EDGE) { $env:REMOVE_EDGE } else { 'true' }
$envRemoveStore = if ($env:REMOVE_STORE) { $env:REMOVE_STORE } else { 'true' }
Write-Info "Policy: win10-nano ignores debloat options (Defender=$envRemoveDefender, Edge=$envRemoveEdge, Store=$envRemoveStore)"
if ($NonInteractive) { Write-Info "NonInteractive mode enabled" }

$isoDrive = "${ISO}:"
if (-not (Test-Path $isoDrive)) { throw "Mounted ISO drive not found: $isoDrive" }

$workspace = Split-Path -Parent $PSCommandPath
$outputIso = Join-Path $workspace 'nano10.iso'
$workRoot = if ($SCRATCH) { "${SCRATCH}:\nano10_work" } else { Join-Path $env:TEMP 'nano10_work' }

Write-Info "ISO drive: $isoDrive"
Write-Info "Working folder: $workRoot"
Write-Info "Output ISO: $outputIso"

New-DirectoryIfMissing $workRoot

Write-Info 'Copying ISO contents (no debloat in stub)...'
robocopy $isoDrive $workRoot /E /NFL /NDL /NJH /NJS /NP | Out-Null

$cmd = Get-Command oscdimg.exe -ErrorAction SilentlyContinue
$oscdimg = $null
if ($cmd) {
    if ($cmd -is [array]) { $cmd = $cmd[0] }
    $oscdimg = ($cmd | Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue)
    if (-not $oscdimg) { $oscdimg = ($cmd | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue) }
}
if ($oscdimg) {
    Write-Info "Found oscdimg: $oscdimg"
    $efi  = Join-Path $workRoot 'efi\microsoft\boot\efisys.bin'
    $boot = Join-Path $workRoot 'boot\etfsboot.com'
    $args = @('-m','-u2','-udfver102')
    if (Test-Path $boot) { $args += @('-b', $boot) }
    if (Test-Path $efi)  { $args += @('-bootdata:2#p0,e,b' + $boot + '#pEF,e,b' + $efi) }
    $args += @($workRoot, $outputIso)
    & $oscdimg @args
    if (-not (Test-Path $outputIso)) { Write-Info 'System oscdimg failed, trying local download...'; $oscdimg = $null }
} else {
    Write-Info 'oscdimg.exe not found in PATH.'
}

if (-not $oscdimg) {
    try {
        $local = Join-Path $PSScriptRoot 'oscdimg.exe'
        if (-not (Test-Path $local)) {
            Write-Info 'Downloading oscdimg.exe...'
            Invoke-WebRequest -Uri 'https://msdl.microsoft.com/download/symbols/oscdimg.exe/3D44737265000/oscdimg.exe' -OutFile $local -ErrorAction Stop
        }
        $efi  = Join-Path $workRoot 'efi\microsoft\boot\efisys.bin'
        $boot = Join-Path $workRoot 'boot\etfsboot.com'
        $args = @('-m','-o','-u2','-udfver102')
        if (Test-Path $boot) { $args += @('-b', $boot) }
        if (Test-Path $efi)  { $args += @('-bootdata:2#p0,e,b' + $boot + '#pEF,e,b' + $efi) }
        $args += @($workRoot, $outputIso)
        & $local @args 2>&1 | Out-Null
    } catch {
        Write-Warning "Failed to run local oscdimg: $($_.Exception.Message)"
    }
}

if (Test-Path $outputIso) {
    Write-Info 'nano10.iso created.'
    $size = (Get-Item $outputIso).Length / 1GB
    Write-Info ("ISO size: {0} GB" -f [math]::Round($size,2))
    exit 0
}

throw 'Failed to create nano10.iso.'

