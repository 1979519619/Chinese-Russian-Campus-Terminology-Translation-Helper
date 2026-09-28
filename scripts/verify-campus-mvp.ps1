param(
    [string]$RuntimeRoot = "",
    [string]$VenvPath = "",
    [int]$Port = 5002,
    [string]$OutputDirectory = ""
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

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $repositoryRoot "artifacts\verification"
}
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$pythonPath = Join-Path $VenvPath "Scripts\python.exe"
$argosPackagesPath = Join-Path $RuntimeRoot "data\argos-translate\packages"
if (-not (Test-Path -LiteralPath $pythonPath -PathType Leaf)) {
    throw "Project Python was not found: $pythonPath. Run scripts\setup-campus-mvp.ps1 first."
}
if (-not (Test-Path -LiteralPath $argosPackagesPath -PathType Container)) {
    throw "Argos model directory was not found: $argosPackagesPath"
}

$dataPath = Join-Path $RuntimeRoot "data"
$cachePath = Join-Path $RuntimeRoot "cache"
$configRoot = Join-Path $RuntimeRoot "config"
$temporaryPath = Join-Path $RuntimeRoot "tmp"
New-Item -ItemType Directory -Force -Path $cachePath, $configRoot, $temporaryPath, $OutputDirectory | Out-Null

$env:XDG_DATA_HOME = $dataPath
$env:XDG_CACHE_HOME = $cachePath
$env:XDG_CONFIG_HOME = $configRoot
$env:ARGOS_PACKAGES_DIR = $argosPackagesPath
$env:TEMP = $temporaryPath
$env:TMP = $temporaryPath
$env:PYTHONIOENCODING = "utf-8"

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportPath = Join-Path $OutputDirectory "campus-mvp-$timestamp.json"
$stdoutPath = Join-Path $OutputDirectory "server-$timestamp.stdout.log"
$stderrPath = Join-Path $OutputDirectory "server-$timestamp.stderr.log"
$summaryPath = Join-Path $OutputDirectory "verification-$timestamp.json"
$baseUrl = "http://127.0.0.1:$Port"
$privacySentinel = "CAMPUS_PRIVACY_SENTINEL_$([guid]::NewGuid().ToString('N'))"
$serverProcess = $null
$verificationPassed = $false

try {
    Write-Host "Checking locked Python dependencies"
    & $pythonPath -m pip check
    if ($LASTEXITCODE -ne 0) { throw "Dependency verification failed." }

    Write-Host "Checking the exact Argos model set"
    & $pythonPath (Join-Path $PSScriptRoot "install-campus-models.py") --check-only
    if ($LASTEXITCODE -ne 0) { throw "Model verification failed." }

    Write-Host "Running the 30-test glossary suite"
    & $pythonPath (Join-Path $repositoryRoot "libretranslate\tests\test_campus_glossary.py")
    if ($LASTEXITCODE -ne 0) { throw "Core glossary tests failed." }

    Write-Host "Starting an isolated verification server at $baseUrl"
    $serverArguments = @(
        "-m", "libretranslate.main",
        "--host", "127.0.0.1",
        "--port", $Port,
        "--load-only", "zh,en,ru"
    )
    $serverProcess = Start-Process -FilePath $pythonPath `
        -ArgumentList $serverArguments `
        -WorkingDirectory $repositoryRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -PassThru

    $healthy = $false
    for ($attempt = 0; $attempt -lt 120; $attempt++) {
        if ($serverProcess.HasExited) {
            throw "Verification server exited early with code $($serverProcess.ExitCode). See $stderrPath"
        }
        try {
            $health = Invoke-RestMethod -Uri "$baseUrl/health" -TimeoutSec 2
            if ($health.status -eq "ok") {
                $healthy = $true
                break
            }
        } catch {
        }
        Start-Sleep -Milliseconds 500
    }
    if (-not $healthy) {
        throw "Verification server did not become healthy within 60 seconds."
    }

    Write-Host "Running the 40-term model-backed evaluation"
    & $pythonPath (Join-Path $PSScriptRoot "evaluate-campus-glossary.py") --base-url $baseUrl --output $reportPath | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Model-backed glossary evaluation failed. See $reportPath" }

    $sentinelBody = @{
        q = $privacySentinel
        source = "en"
        target = "ru"
        format = "text"
        use_glossary = $false
    } | ConvertTo-Json
    $null = Invoke-RestMethod -Uri "$baseUrl/translate" -Method Post -ContentType "application/json; charset=utf-8" -Body $sentinelBody -TimeoutSec 60

    $report = Get-Content -LiteralPath $reportPath -Raw -Encoding utf8 | ConvertFrom-Json
    if ($report.termCount -ne 40 -or $report.passedCount -ne 40 -or $report.adoptionRatePercent -ne 100) {
        throw "Expected 40/40 term adoption, found $($report.passedCount)/$($report.termCount)."
    }
    if (-not $report.ordinaryTextRegression.identical) {
        throw "Ordinary-text regression check failed."
    }
    if (@($report.comparisons).Count -ne 3) {
        throw "Expected three baseline/enhanced comparisons."
    }

    $verificationPassed = $true
} finally {
    if ($serverProcess -and -not $serverProcess.HasExited) {
        Stop-Process -Id $serverProcess.Id -Force
        $serverProcess.WaitForExit()
    }
}

$combinedLog = ""
if (Test-Path -LiteralPath $stdoutPath) { $combinedLog += Get-Content -LiteralPath $stdoutPath -Raw -Encoding utf8 }
if (Test-Path -LiteralPath $stderrPath) { $combinedLog += Get-Content -LiteralPath $stderrPath -Raw -Encoding utf8 }
if ($combinedLog.Contains($privacySentinel)) {
    throw "Privacy check failed: request text appeared in the server logs."
}

$summary = [ordered]@{
    status = if ($verificationPassed) { "PASS" } else { "FAIL" }
    verifiedAt = (Get-Date).ToString("o")
    repository = $repositoryRoot
    runtimeRoot = $RuntimeRoot
    venvPath = $VenvPath
    dependencyCheck = "PASS"
    modelSet = "zh-en,en-zh,ru-en,en-ru@1.9"
    unitTests = "30/30"
    termAdoption = "40/40"
    ordinaryTextRegression = "PASS"
    privacyLogSentinel = "PASS"
    evaluationReport = $reportPath
}
$summary | ConvertTo-Json | Set-Content -LiteralPath $summaryPath -Encoding utf8
Write-Host "VERIFY_PASS"
Write-Host "Summary: $summaryPath"
Write-Host "Evaluation: $reportPath"
