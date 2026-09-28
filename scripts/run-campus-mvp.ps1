param(
    [int]$Port = 0,
    [string]$ListenAddress = "",
    [string]$RuntimeRoot = "",
    [string]$VenvPath = "",
    [switch]$OpenBrowser
)

$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repositoryRoot ".campus-mvp.local.json"
$localConfig = $null
if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    $localConfig = Get-Content -LiteralPath $configPath -Raw -Encoding utf8 | ConvertFrom-Json
}

if (-not $RuntimeRoot) {
    if ($localConfig -and $localConfig.runtimeRoot) {
        $RuntimeRoot = $localConfig.runtimeRoot
    } elseif (Test-Path -LiteralPath "F:\LT-Campus-MVP\runtime") {
        $RuntimeRoot = "F:\LT-Campus-MVP\runtime"
    } else {
        $RuntimeRoot = Join-Path $env:SystemDrive "LT-Campus-MVP\runtime"
    }
}
$RuntimeRoot = [System.IO.Path]::GetFullPath($RuntimeRoot)

if (-not $VenvPath) {
    if ($localConfig -and $localConfig.venvPath) {
        $VenvPath = $localConfig.venvPath
    } else {
        $legacyVenvPath = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot "..\runtime\.venv"))
        if (Test-Path -LiteralPath (Join-Path $legacyVenvPath "Scripts\python.exe") -PathType Leaf) {
            $VenvPath = $legacyVenvPath
        } else {
            $VenvPath = Join-Path $RuntimeRoot ".venv"
        }
    }
}
$VenvPath = [System.IO.Path]::GetFullPath($VenvPath)

if (-not $ListenAddress) {
    $ListenAddress = if ($localConfig -and $localConfig.listenAddress) { $localConfig.listenAddress } else { "127.0.0.1" }
}
if ($Port -eq 0) {
    $Port = if ($localConfig -and $localConfig.port) { [int]$localConfig.port } else { 5000 }
}

$pythonPath = Join-Path $VenvPath "Scripts\python.exe"
$modelDataPath = Join-Path $RuntimeRoot "data"
$modelCachePath = Join-Path $RuntimeRoot "cache"
$modelConfigPath = Join-Path $RuntimeRoot "config"
$temporaryPath = Join-Path $RuntimeRoot "tmp"
$argosPackagesPath = Join-Path $modelDataPath "argos-translate\packages"

if (-not (Test-Path -LiteralPath $pythonPath -PathType Leaf)) {
    throw "Project Python was not found: $pythonPath. Run scripts\setup-campus-mvp.ps1 first."
}

if (-not (Test-Path -LiteralPath $argosPackagesPath -PathType Container)) {
    throw "Argos model directory was not found: $argosPackagesPath"
}

New-Item -ItemType Directory -Force -Path $modelCachePath, $modelConfigPath, $temporaryPath | Out-Null

$env:XDG_DATA_HOME = $modelDataPath
$env:XDG_CACHE_HOME = $modelCachePath
$env:XDG_CONFIG_HOME = $modelConfigPath
$env:ARGOS_PACKAGES_DIR = $argosPackagesPath
$env:TEMP = $temporaryPath
$env:TMP = $temporaryPath
$env:PYTHONIOENCODING = "utf-8"

Set-Location -LiteralPath $repositoryRoot
if ($OpenBrowser) {
    $healthUrl = "http://${ListenAddress}:${Port}/health"
    $pageUrl = "http://${ListenAddress}:${Port}"
    Start-Job -ScriptBlock {
        param($HealthUrl, $PageUrl)
        for ($attempt = 0; $attempt -lt 120; $attempt++) {
            try {
                $health = Invoke-RestMethod -Uri $HealthUrl -TimeoutSec 2
                if ($health.status -eq "ok") {
                    Start-Process $PageUrl
                    return
                }
            } catch {
            }
            Start-Sleep -Milliseconds 500
        }
    } -ArgumentList $healthUrl, $pageUrl | Out-Null
}
& $pythonPath -m libretranslate.main --host $ListenAddress --port $Port --load-only zh,en,ru
exit $LASTEXITCODE
