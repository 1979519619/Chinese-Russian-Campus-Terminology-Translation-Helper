param(
    [int]$Port = 5000,
    [string]$ListenAddress = "127.0.0.1",
    [string]$RuntimeRoot = "F:\LT-Campus-MVP\runtime"
)

$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$pythonPath = Join-Path $repositoryRoot "..\runtime\.venv\Scripts\python.exe"
$pythonPath = [System.IO.Path]::GetFullPath($pythonPath)
$modelDataPath = Join-Path $RuntimeRoot "data"
$modelCachePath = Join-Path $RuntimeRoot "cache"
$modelConfigPath = Join-Path $RuntimeRoot "config"
$temporaryPath = Join-Path $RuntimeRoot "tmp"
$argosPackagesPath = Join-Path $modelDataPath "argos-translate\packages"

if (-not (Test-Path -LiteralPath $pythonPath -PathType Leaf)) {
    throw "Project Python was not found: $pythonPath"
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
& $pythonPath -m libretranslate.main --host $ListenAddress --port $Port --load-only zh,en,ru
exit $LASTEXITCODE
