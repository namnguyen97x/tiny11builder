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
$isoDrive = "${ISO}:"
if (-not (Test-Path $isoDrive)) { throw "Mounted ISO drive not found: $isoDrive" }

$workspace = Split-Path -Parent $PSCommandPath
$outputIso = Join-Path $workspace 'tiny10.iso'
$workRoot = if ($SCRATCH) { "${SCRATCH}:\tiny10_work" } else { Join-Path $env:TEMP 'tiny10_work' }

Write-Info "ISO drive: $isoDrive"
Write-Info "Working folder: $workRoot"
Write-Info "Output ISO: $outputIso"

New-DirectoryIfMissing $workRoot

# Copy ISO contents to work folder
Write-Info 'Copying ISO contents...'
robocopy $isoDrive $workRoot /E /NFL /NDL /NJH /NJS /NP | Out-Null

# Best-effort: try to rebuild ISO; fallback to local oscdimg download if needed
$cmd = Get-Command oscdimg.exe -ErrorAction SilentlyContinue
$oscdimg = $null
if ($cmd) {
    if ($cmd -is [array]) { $cmd = $cmd[0] }
    $oscdimg = ($cmd | Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue)
    if (-not $oscdimg) { $oscdimg = ($cmd | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue) }
}
if ($oscdimg) {
    Write-Info "Found oscdimg: $oscdimg"
    $efiBin       = Join-Path $workRoot 'efi\microsoft\boot\efisys.bin'
    $efiNoPrompt  = Join-Path $workRoot 'efi\microsoft\boot\efisys_noprompt.bin'
    $etfsBoot     = Join-Path $workRoot 'boot\etfsboot.com'

    function Invoke-Oscdimg([string]$exe) {
        if (Test-Path $outputIso) { Remove-Item $outputIso -Force -ErrorAction SilentlyContinue }
        $common = @('-m','-u2','-udfver102')
        # 1) Try BIOS+UEFI
        if (Test-Path $etfsBoot -and (Test-Path $efiBin -or Test-Path $efiNoPrompt)) {
            $efiUse = if (Test-Path $efiBin) { $efiBin } else { $efiNoPrompt }
            & $exe @($common + @('-b', $etfsBoot, "-bootdata:2#p0,e,b$etfsBoot#pEF,e,b$efiUse", $workRoot, $outputIso)) 2>&1 | Out-Null
            if (Test-Path $outputIso) { return $true }
        }
        # 2) Try BIOS-only
        if (Test-Path $etfsBoot) {
            & $exe @($common + @('-b', $etfsBoot, $workRoot, $outputIso)) 2>&1 | Out-Null
            if (Test-Path $outputIso) { return $true }
        }
        # 3) Try UEFI-only
        if (Test-Path $efiBin -or Test-Path $efiNoPrompt) {
            $efiUse = if (Test-Path $efiBin) { $efiBin } else { $efiNoPrompt }
            & $exe @($common + @("-bootdata:1#pEF,e,b$efiUse", $workRoot, $outputIso)) 2>&1 | Out-Null
            if (Test-Path $outputIso) { return $true }
        }
        # 4) Non-bootable ISO fallback
        & $exe @($common + @($workRoot, $outputIso)) 2>&1 | Out-Null
        return (Test-Path $outputIso)
    }

    if (-not (Invoke-Oscdimg -exe $oscdimg)) { Write-Info 'System oscdimg failed, trying local download...'; $oscdimg = $null }
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
        $efiBin       = Join-Path $workRoot 'efi\microsoft\boot\efisys.bin'
        $efiNoPrompt  = Join-Path $workRoot 'efi\microsoft\boot\efisys_noprompt.bin'
        $etfsBoot     = Join-Path $workRoot 'boot\etfsboot.com'
        function Invoke-LocalOscdimg { param([string]$exe)
            if (Test-Path $outputIso) { Remove-Item $outputIso -Force -ErrorAction SilentlyContinue }
            $common = @('-m','-o','-u2','-udfver102')
            if (Test-Path $etfsBoot -and (Test-Path $efiBin -or Test-Path $efiNoPrompt)) {
                $efiUse = if (Test-Path $efiBin) { $efiBin } else { $efiNoPrompt }
                & $exe @($common + @('-b', $etfsBoot, "-bootdata:2#p0,e,b$etfsBoot#pEF,e,b$efiUse", $workRoot, $outputIso)) 2>&1 | Out-Null
                if (Test-Path $outputIso) { return $true }
            }
            if (Test-Path $etfsBoot) {
                & $exe @($common + @('-b', $etfsBoot, $workRoot, $outputIso)) 2>&1 | Out-Null
                if (Test-Path $outputIso) { return $true }
            }
            if (Test-Path $efiBin -or Test-Path $efiNoPrompt) {
                $efiUse = if (Test-Path $efiBin) { $efiBin } else { $efiNoPrompt }
                & $exe @($common + @("-bootdata:1#pEF,e,b$efiUse", $workRoot, $outputIso)) 2>&1 | Out-Null
                if (Test-Path $outputIso) { return $true }
            }
            & $exe @($common + @($workRoot, $outputIso)) 2>&1 | Out-Null
            return (Test-Path $outputIso)
        }
        [void](Invoke-LocalOscdimg -exe $local)
    } catch {
        Write-Warning "Failed to run local oscdimg: $($_.Exception.Message)"
    }
}

if (Test-Path $outputIso) {
    Write-Info 'tiny10.iso created.'
    $size = (Get-Item $outputIso).Length / 1GB
    Write-Info ("ISO size: {0} GB" -f [math]::Round($size,2))
    exit 0
}

throw 'Failed to create tiny10.iso.'

