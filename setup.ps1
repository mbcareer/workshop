#requires -Version 5.1
<#
.SYNOPSIS
  One-command Windows setup for the VS Code + Databricks + Ralph workshop.
.DESCRIPTION
  Uses uv (no Python or Node.js installation required on PATH) to provision
  Python 3.12, install workshop dependencies, copy the local .env template,
  and run offline tests. Optionally offers an approved Databricks CLI install,
  browser-based OAuth login, and endpoint configuration.
.EXAMPLE
  .\setup.ps1
.EXAMPLE
  .\setup.ps1 -WorkspaceUrl 'https://YOUR-WORKSPACE-HOST' -Endpoint 'YOUR_APPROVED_ENDPOINT'
.EXAMPLE
  .\setup.ps1 -NonInteractive -SkipDatabricks
.EXAMPLE
  .\setup.ps1 -LaunchGame
#>
[CmdletBinding()]
param(
    [string]$WorkspaceUrl = '',
    [string]$Endpoint = '',
    [string]$Profile = 'WORKSHOP',
    [switch]$InstallDatabricksCli,
    [switch]$SkipDatabricks,
    [switch]$NonInteractive,
    [switch]$LaunchGame
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = $PSScriptRoot
$workshop = Join-Path $repo 'workshop'
$requirements = Join-Path $workshop 'requirements.txt'
$envTemplate = Join-Path $workshop '.env.example'
$envFile = Join-Path $workshop '.env'
$venvDir = Join-Path $workshop '.venv'
$venvPython = Join-Path $venvDir 'Scripts\python.exe'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Step([string]$message) { Write-Host "`n==> $message" -ForegroundColor Cyan }
function Info([string]$message) { Write-Host "    $message" }
function Warn([string]$message) { Write-Warning $message }

function Run-External {
    param([string]$File, [string[]]$Arguments, [string]$Description)
    # Tools such as uv use stderr for ordinary progress messages on Windows.
    # Judge success by the process exit code, not by the output stream.
    $prior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $File @Arguments
        $toolExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prior
    }
    if ($toolExitCode -ne 0) {
        throw "$Description failed (exit code $toolExitCode). Check the message above."
    }
}

function Set-LocalEnvValue {
    param([string]$Key, [string]$Value)
    # Values are non-secret, single-line config strings only.
    if ($Value -match '[\r\n#=]' -or $Value -match '\s') {
        throw "Invalid $Key value. Enter a single value without spaces, #, or =."
    }
    $lines = New-Object 'System.Collections.Generic.List[string]'
    foreach ($line in [System.IO.File]::ReadAllLines($envFile)) { $lines.Add($line) }
    $pattern = '^\s*#?\s*' + [regex]::Escape($Key) + '\s*='
    $found = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $pattern) {
            if (-not $found) {
                $lines[$i] = "$Key=$Value"
                $found = $true
            } else {
                $lines.RemoveAt($i)
                $i--
            }
        }
    }
    if (-not $found) { $lines.Add("$Key=$Value") }
    [System.IO.File]::WriteAllLines($envFile, $lines.ToArray(), $utf8NoBom)
}

function Get-LocalEnvValue([string]$Key) {
    $pattern = '^\s*' + [regex]::Escape($Key) + '\s*=\s*(.*)\s*$'
    foreach ($line in [System.IO.File]::ReadAllLines($envFile)) {
        if ($line -match $pattern) { return $Matches[1].Trim() }
    }
    return ''
}

try {
    if (-not (Test-Path $requirements) -or -not (Test-Path $envTemplate)) {
        throw "Workshop files are missing. Run this script from the extracted repository, not by copying setup.ps1 alone."
    }
    Step 'Checking uv'
    $uv = Get-Command uv -ErrorAction SilentlyContinue
    if (-not $uv) {
        throw "uv is not on PATH. Ask IT for an approved uv installation (or see https://docs.astral.sh/uv/getting-started/installation/), then rerun .\setup.ps1."
    }
    Run-External -File $uv.Source -Arguments @('--version') -Description 'uv version check'

    Step 'Provisioning Python 3.12 via uv (no python command required)'
    Run-External -File $uv.Source -Arguments @('python', 'install', '3.12') -Description 'uv Python install'

    Step 'Preparing the local workshop environment'
    if (-not (Test-Path $venvPython)) {
        Run-External -File $uv.Source -Arguments @('venv', $venvDir, '--python', '3.12') -Description 'virtual environment creation'
    } else {
        Info 'Using existing workshop/.venv (not deleting your environment).'
    }
    if (-not (Test-Path $venvPython)) { throw 'Python executable not found in workshop/.venv after setup.' }
    Run-External -File $venvPython -Arguments @('-c', 'import sys; assert sys.version_info[:2] == (3, 12), "Expected Python 3.12"') -Description 'Python version check'
    Run-External -File $uv.Source -Arguments @('pip', 'install', '--python', $venvPython, '-r', $requirements) -Description 'Python dependency installation'

    Step 'Preparing local configuration (never committed to Git)'
    if (-not (Test-Path $envFile)) {
        Copy-Item -LiteralPath $envTemplate -Destination $envFile
        Info 'Created workshop/.env from the safe example.'
    } else {
        Info 'Preserved your existing workshop/.env.'
    }

    Step 'Running offline smoke tests'
    Push-Location $workshop
    try {
        Run-External -File $venvPython -Arguments @('-m', 'unittest', 'discover', '-s', 'tests', '-v') -Description 'offline workshop tests'
    } finally {
        Pop-Location
    }
    Info 'Local Python and game prerequisites are ready.'

    if (-not $SkipDatabricks) {
        Step 'Optional Databricks setup (needed only for the LLM exercises)'
        $cli = Get-Command databricks -ErrorAction SilentlyContinue
        if (-not $cli) {
            $doInstall = [bool]$InstallDatabricksCli
            $winget = Get-Command winget -ErrorAction SilentlyContinue
            if (-not $doInstall -and -not $NonInteractive -and $winget) {
                Info 'The Databricks CLI is not installed. Use winget only if your company permits it.'
                $choice = (Read-Host 'Install the official Databricks CLI using winget? (y/N)').Trim()
                if ($choice -match '^(y|yes)$') { $doInstall = $true }
            }
            if ($doInstall) {
                if (-not $winget) {
                    Warn 'winget is unavailable; ask IT to install the current Databricks CLI.'
                } else {
                    Info 'Installing the official Databricks CLI through winget...'
                    try {
                        Run-External -File $winget.Source -Arguments @('install', '--id', 'Databricks.DatabricksCLI', '--exact', '--accept-source-agreements', '--accept-package-agreements') -Description 'Databricks CLI installation'
                    } catch {
                        Warn 'Databricks CLI installation did not complete. Offline exercises are still available.'
                    }
                    $cli = Get-Command databricks -ErrorAction SilentlyContinue
                    if (-not $cli) {
                        Warn 'If winget succeeded, restart your VS Code terminal and rerun setup.ps1 so PATH refreshes.'
                    }
                }
            }
        }

        if ($cli) {
            try {
                Run-External -File $cli.Source -Arguments @('-v') -Description 'Databricks CLI version check'
            } catch {
                Warn 'Could not confirm Databricks CLI version.'
            }
            if (-not $WorkspaceUrl -and -not $NonInteractive) {
                $WorkspaceUrl = (Read-Host 'Approved Databricks workspace URL (Enter to skip OAuth login)').Trim()
            }
            if ($WorkspaceUrl) {
                $WorkspaceUrl = $WorkspaceUrl.TrimEnd('/')
                $parsedUrl = $null
                if (-not [Uri]::TryCreate($WorkspaceUrl, [UriKind]::Absolute, [ref]$parsedUrl) -or
                    $parsedUrl.Scheme -ne 'https' -or $parsedUrl.AbsolutePath -ne '/' -or
                    $parsedUrl.Query -or $parsedUrl.Fragment) {
                    throw 'WorkspaceUrl must be an HTTPS workspace host, e.g. https://YOUR-WORKSPACE-HOST (no path or query).'
                }
                if ($Profile -notmatch '^[a-zA-Z0-9._-]+$') { throw 'Profile may contain only letters, numbers, dots, underscores, and hyphens.' }
                Info "Signing in via your browser to $WorkspaceUrl as profile $Profile (no tokens requested by this script)."
                try {
                    Run-External -File $cli.Source -Arguments @('auth', 'login', '--host', $WorkspaceUrl, '--profile', $Profile) -Description 'Databricks OAuth login'
                    Set-LocalEnvValue -Key 'DATABRICKS_CONFIG_PROFILE' -Value $Profile
                    Info 'OAuth profile configured. The profile name is saved in local workshop/.env.'
                } catch {
                    Warn 'Databricks login was not completed; local exercises still work.'
                }
            } else {
                Info 'Skipped OAuth login. You can rerun setup.ps1 with -WorkspaceUrl when ready.'
            }
        } else {
            Info 'No Databricks CLI available. Ask IT for an approved install; local game works without it.'
            Info 'Official Windows option (only if approved): winget install Databricks.DatabricksCLI'
        }

        $existingEndpoint = Get-LocalEnvValue -Key 'DATABRICKS_ENDPOINT'
        if (-not $Endpoint -and ($existingEndpoint -eq '' -or $existingEndpoint -like 'REPLACE_*') -and -not $NonInteractive) {
            $Endpoint = (Read-Host 'Approved chat serving endpoint name (Enter to skip)').Trim()
        }
        if ($Endpoint) {
            if ($Endpoint -notmatch '^[a-zA-Z0-9][a-zA-Z0-9._-]*$') {
                throw 'Endpoint must be a serving endpoint NAME (letters/numbers/dots/underscores/hyphens), not a URL.'
            }
            Set-LocalEnvValue -Key 'DATABRICKS_ENDPOINT' -Value $Endpoint
            Info 'Saved the approved endpoint name to workshop/.env (ignored by Git).'
        } else {
            if ($existingEndpoint -eq '' -or $existingEndpoint -like 'REPLACE_*') {
                Info 'No endpoint configured yet; the offline game still works.'
            } else {
                Info 'Preserved your existing approved endpoint name.'
            }
        }
    } else {
        Info 'Skipped Databricks setup as requested.'
    }

    Step 'Setup finished'
    Write-Host 'Offline workshop setup: READY' -ForegroundColor Green
    Write-Host 'Next, run these commands from the repo root:'
    Write-Host '    cd workshop'
    Write-Host '    uv run 03_play_game.py                       # play offline (no Databricks)'
    Write-Host '    uv run 02_ralph_game.py --dry-run           # preview the loop (no API call)'
    Write-Host '    uv run 01_llm_call.py                       # requires approved endpoint/login'
    Write-Host '    uv run 02_ralph_game.py --max-iterations 2  # uses up to two model calls'
    Write-Host '    uv run 02_ralph_game.py --reset             # restore starter game'
    Write-Host 'Do not commit workshop/.env or OAuth credentials. Node.js is optional.'

    if ($LaunchGame) {
        Step 'Starting the local browser game; press Ctrl+C to stop it'
        Push-Location $workshop
        try { Run-External -File $venvPython -Arguments @('03_play_game.py') -Description 'local game server' }
        finally { Pop-Location }
    }
} catch {
    Write-Host "`nSETUP STOPPED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'See docs/UV_SETUP.md; do not bypass company-managed device policies.'
    exit 1
}
