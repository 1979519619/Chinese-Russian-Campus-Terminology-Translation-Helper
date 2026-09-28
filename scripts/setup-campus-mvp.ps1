param(
    [string]$RuntimeRoot = "",
    [string]$VenvPath = "",
    [string]$PythonExecutable = "",
    [int]$Port = 5000,
    [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"
$MinimumRuntimeFreeGiB = 2
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repositoryRoot ".campus-mvp.local.json"
$lockPath = Join-Path $repositoryRoot "requirements-mvp-lock.txt"

function Resolve-Python312 {
    param([string]$RequestedPython)

    $candidates = [System.Collections.Generic.List[string]]::new()
    if ($RequestedPython) {
        if (-not (Test-Path -LiteralPath $RequestedPython -PathType Leaf)) {
            throw "Python executable was not found: $RequestedPython"
        }
        $candidates.Add([System.IO.Path]::GetFullPath($RequestedPython))
    } elseif (Get-Command py -ErrorAction SilentlyContinue) {
        $launcherOutput = & py -3.12 -c "import sys; print(sys.executable)" 2>$null | Select-Object -Last 1
        if ($LASTEXITCODE -eq 0 -and $launcherOutput) {
            $candidates.Add($launcherOutput.Trim())
        }
    }

    if (-not $RequestedPython) {
        $knownPaths = @(
            (Join-Path $env:LOCALAPPDATA "Programs\Python\Python312\python.exe"),
            (Join-Path $env:ProgramFiles "Python312\python.exe")
        )
        foreach ($knownPath in $knownPaths) {
            if (Test-Path -LiteralPath $knownPath -PathType Leaf) {
                $candidates.Add([System.IO.Path]::GetFullPath($knownPath))
            }
        }
        $pathCommand = Get-Command python -ErrorAction SilentlyContinue
        if ($pathCommand -and $pathCommand.Source -notmatch "\\WindowsApps\\") {
            $candidates.Add($pathCommand.Source)
        }
    }

    foreach ($candidate in $candidates | Select-Object -Unique) {
        $identity = & $candidate -c "import json,platform,sys; print(json.dumps({'version': list(sys.version_info[:2]), 'bits': platform.architecture()[0]}))" 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $identity) {
            continue
        }
        $pythonInfo = $identity | ConvertFrom-Json
        if ($pythonInfo.version[0] -eq 3 -and $pythonInfo.version[1] -eq 12 -and $pythonInfo.bits -eq "64bit") {
            return $candidate
        }
    }

    if ($RequestedPython) {
        throw "Expected 64-bit Python 3.12 at $RequestedPython."
    }
    throw "64-bit Python 3.12 was not found. Install it or pass -PythonExecutable with its full path."
}

function Get-DriveFact {
    param([string]$PathValue)

    $fullPath = [System.IO.Path]::GetFullPath($PathValue)
    $root = [System.IO.Path]::GetPathRoot($fullPath)
    $driveName = $root.TrimEnd('\').TrimEnd(':')
    $drive = Get-PSDrive -Name $driveName -PSProvider FileSystem -ErrorAction Stop
    return [pscustomobject]@{
        Path = $fullPath
        Drive = $driveName
        FreeGiB = [math]::Round($drive.Free / 1GB, 2)
    }
}

if (-not $RuntimeRoot) {
    if (Test-Path -LiteralPath "F:\") {
        $RuntimeRoot = "F:\LT-Campus-MVP\runtime"
    } else {
        $RuntimeRoot = Join-Path $env:SystemDrive "LT-Campus-MVP\runtime"
    }
}
$RuntimeRoot = [System.IO.Path]::GetFullPath($RuntimeRoot)
if ($RuntimeRoot -match "[^\x00-\x7F]") {
    throw "RuntimeRoot must use an ASCII-only path because SentencePiece cannot reliably open non-ASCII model paths on Windows: $RuntimeRoot"
}

if (-not $VenvPath) {
    $VenvPath = Join-Path $RuntimeRoot ".venv"
}
$VenvPath = [System.IO.Path]::GetFullPath($VenvPath)
$basePython = Resolve-Python312 -RequestedPython $PythonExecutable
$runtimeDrive = Get-DriveFact -PathValue $RuntimeRoot
$venvDrive = Get-DriveFact -PathValue $VenvPath

if ($runtimeDrive.FreeGiB -lt $MinimumRuntimeFreeGiB) {
    throw "Runtime drive $($runtimeDrive.Drive): has only $($runtimeDrive.FreeGiB) GiB free; at least $MinimumRuntimeFreeGiB GiB is required."
}
if ($venvDrive.FreeGiB -lt 1) {
    throw "Virtual-environment drive $($venvDrive.Drive): has only $($venvDrive.FreeGiB) GiB free; at least 1 GiB is required."
}

$plan = [pscustomobject]@{
    Repository = $repositoryRoot
    Python = $basePython
    RuntimeRoot = $RuntimeRoot
    RuntimeDrive = $runtimeDrive.Drive
    RuntimeFreeGiB = $runtimeDrive.FreeGiB
    VenvPath = $VenvPath
    VenvDrive = $venvDrive.Drive
    Port = $Port
    EstimatedFinalGiB = 1.0
    ValidateOnly = [bool]$ValidateOnly
}
$plan | ConvertTo-Json
if ($ValidateOnly) {
    Write-Host "SETUP_PREFLIGHT_PASS"
    exit 0
}

$dataPath = Join-Path $RuntimeRoot "data"
$cachePath = Join-Path $RuntimeRoot "cache"
$configRoot = Join-Path $RuntimeRoot "config"
$temporaryPath = Join-Path $RuntimeRoot "tmp"
$pipCachePath = Join-Path $cachePath "pip"
$argosPackagesPath = Join-Path $dataPath "argos-translate\packages"
New-Item -ItemType Directory -Force -Path $dataPath, $cachePath, $configRoot, $temporaryPath, $pipCachePath | Out-Null

$env:XDG_DATA_HOME = $dataPath
$env:XDG_CACHE_HOME = $cachePath
$env:XDG_CONFIG_HOME = $configRoot
$env:ARGOS_PACKAGES_DIR = $argosPackagesPath
$env:PIP_CACHE_DIR = $pipCachePath
$env:TEMP = $temporaryPath
$env:TMP = $temporaryPath
$env:PYTHONIOENCODING = "utf-8"

$venvPython = Join-Path $VenvPath "Scripts\python.exe"
if (-not (Test-Path -LiteralPath $venvPython -PathType Leaf)) {
    Write-Host "Creating Python virtual environment at $VenvPath"
    & $basePython -m venv $VenvPath
    if ($LASTEXITCODE -ne 0) { throw "Failed to create the virtual environment." }
}

Write-Host "Installing locked Python dependencies"
& $venvPython -m pip install --upgrade "pip==26.2.1" "setuptools==84.0.0" "wheel==0.45.1"
if ($LASTEXITCODE -ne 0) { throw "Failed to prepare pip tooling." }
& $venvPython -m pip install --no-deps -r $lockPath
if ($LASTEXITCODE -ne 0) { throw "Failed to install locked dependencies." }
& $venvPython -m pip check
if ($LASTEXITCODE -ne 0) { throw "Dependency verification failed." }

Write-Host "Installing the pinned campus translation model set"
& $venvPython (Join-Path $PSScriptRoot "install-campus-models.py")
if ($LASTEXITCODE -ne 0) { throw "Model installation or verification failed." }

Write-Host "Running the dependency-free glossary tests"
& $venvPython (Join-Path $repositoryRoot "libretranslate\tests\test_campus_glossary.py")
if ($LASTEXITCODE -ne 0) { throw "Core glossary tests failed." }

$commit = (& git -C $repositoryRoot rev-parse HEAD 2>$null | Select-Object -Last 1).Trim()
$localConfig = [ordered]@{
    runtimeRoot = $RuntimeRoot
    venvPath = $VenvPath
    listenAddress = "127.0.0.1"
    port = $Port
    pythonVersion = "3.12"
    modelVersion = "1.9"
    sourceCommit = $commit
}
$localConfig | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding utf8

Write-Host "SETUP_PASS"
Write-Host "Local configuration: $configPath"
Write-Host "Start the service with: .\scripts\start-campus-mvp.cmd"
