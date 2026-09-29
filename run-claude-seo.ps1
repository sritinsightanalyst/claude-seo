[CmdletBinding()]
param(
    [string]$Url
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RuntimeScript = Join-Path $RepoRoot "scripts\runtime.py"
$env:CLAUDE_SEO_DATA_DIR = $RepoRoot

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$ShowOutput
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $hasNativePreference = $null -ne (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue)
    if ($hasNativePreference) {
        $previousNativePreference = $PSNativeCommandUseErrorActionPreference
    }

    try {
        $ErrorActionPreference = "Continue"
        if ($hasNativePreference) {
            $PSNativeCommandUseErrorActionPreference = $false
        }

        if ($ShowOutput) {
            & $Executable @Arguments
            $exitCode = $LASTEXITCODE
            $output = @()
        } else {
            $output = @(& $Executable @Arguments 2>&1 | ForEach-Object { $_.ToString() })
            $exitCode = $LASTEXITCODE
        }
    } catch {
        $exitCode = 1
        $output = @($_.Exception.Message)
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
        if ($hasNativePreference) {
            $PSNativeCommandUseErrorActionPreference = $previousNativePreference
        }
    }

    return [pscustomobject]@{ ExitCode = $exitCode; Output = $output }
}

function Find-Python {
    $candidates = @(
        @{ Exe = "py"; Prefix = @("-3") },
        @{ Exe = "python3"; Prefix = @() },
        @{ Exe = "python"; Prefix = @() }
    )
    $probeCode = "import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)"

    foreach ($candidate in $candidates) {
        $command = Get-Command -Name $candidate.Exe -CommandType Application -ErrorAction SilentlyContinue
        if ($null -eq $command) {
            continue
        }

        $probeArgs = @($candidate.Prefix) + @("-c", $probeCode)
        $probe = Invoke-NativeCommand -Executable $command.Source -Arguments $probeArgs
        if ($probe.ExitCode -eq 0) {
            return [pscustomobject]@{
                Exe = $command.Source
                Prefix = @($candidate.Prefix)
            }
        }
    }

    return $null
}

if (-not (Test-Path -LiteralPath $RuntimeScript -PathType Leaf)) {
    Write-Host "Claude SEO runtime is missing: $RuntimeScript" -ForegroundColor Red
    exit 1
}

$claude = Get-Command -Name "claude" -CommandType Application -ErrorAction SilentlyContinue
if ($null -eq $claude) {
    Write-Host "Claude Code CLI was not found on PATH." -ForegroundColor Red
    Write-Host "Install Claude Code, sign in, then run this script again:" -ForegroundColor Yellow
    Write-Host "https://code.claude.com/docs/en/quickstart"
    exit 1
}

$python = Find-Python
if ($null -eq $python) {
    Write-Host "Python 3.10 or newer is required. Install Python, then run this script again." -ForegroundColor Red
    exit 1
}

if ([string]::IsNullOrWhiteSpace($Url)) {
    $Url = Read-Host "Enter the website to audit"
}

$Url = $Url.Trim()
if ($Url -notmatch "^https?://") {
    $Url = "https://$Url"
}

$siteUri = $null
$validUrl = [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$siteUri)
if (-not $validUrl -or $siteUri.Scheme -notin @("http", "https") -or [string]::IsNullOrWhiteSpace($siteUri.Host)) {
    Write-Host "Enter a valid website address, such as example.com or https://example.com." -ForegroundColor Red
    exit 1
}

Write-Host "Checking Claude SEO runtime..." -ForegroundColor Cyan
$doctorArgs = @($python.Prefix) + @($RuntimeScript, "doctor", "--json")
$doctor = Invoke-NativeCommand -Executable $python.Exe -Arguments $doctorArgs
$runtimeStatus = $null
try {
    $runtimeStatus = ($doctor.Output -join "`n") | ConvertFrom-Json -ErrorAction Stop
} catch {
    $runtimeStatus = $null
}

if ($doctor.ExitCode -ne 0 -or $null -eq $runtimeStatus -or -not $runtimeStatus.ready -or -not $runtimeStatus.browser_ready) {
    Write-Host "Preparing the isolated Python runtime and Chromium. This can take a few minutes..." -ForegroundColor Yellow
    $setupArgs = @($python.Prefix) + @($RuntimeScript, "setup")
    $setup = Invoke-NativeCommand -Executable $python.Exe -Arguments $setupArgs -ShowOutput
    if ($setup.ExitCode -notin @(0, 10)) {
        Write-Host "Claude SEO runtime setup failed." -ForegroundColor Red
        exit $setup.ExitCode
    }

    $doctor = Invoke-NativeCommand -Executable $python.Exe -Arguments $doctorArgs
    try {
        $runtimeStatus = ($doctor.Output -join "`n") | ConvertFrom-Json -ErrorAction Stop
    } catch {
        $runtimeStatus = $null
    }
    if ($doctor.ExitCode -ne 0 -or $null -eq $runtimeStatus -or -not $runtimeStatus.ready) {
        Write-Host "Claude SEO runtime is still not ready. Run scripts\runtime.py doctor for details." -ForegroundColor Red
        exit 1
    }
}

if (-not $runtimeStatus.browser_ready) {
    Write-Host "Chromium is unavailable; the audit can run, but rendered-page checks may be limited." -ForegroundColor Yellow
}

Write-Host "Starting the Claude SEO audit for $Url" -ForegroundColor Cyan
Write-Host "Approve Claude Code tool requests as they appear. Audit files will be written under the repo." -ForegroundColor Gray
Write-Host "After reviewing the results, type /exit in Claude Code to open the report folder." -ForegroundColor Gray
$auditStarted = Get-Date
$claudeArgs = @("--plugin-dir", $RepoRoot, "/seo audit $Url")
Push-Location -LiteralPath $RepoRoot
try {
    & $claude.Source @claudeArgs
    $claudeExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}

if ($claudeExitCode -ne 0) {
    Write-Host "Claude Code exited with status $claudeExitCode." -ForegroundColor Red
    exit $claudeExitCode
}

$results = Get-ChildItem -LiteralPath $RepoRoot -Directory -Filter "*-audit" -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -ge $auditStarted } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if ($null -ne $results) {
    Write-Host "Audit results: $($results.FullName)" -ForegroundColor Green
    $quotedPath = '"{0}"' -f $results.FullName
    Start-Process -FilePath "explorer.exe" -ArgumentList $quotedPath
} else {
    Write-Host "Claude Code finished. Check the Claude Code transcript for the audit results." -ForegroundColor Yellow
}