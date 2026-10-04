# Stop the local AzerothCore Docker Compose stack without deleting its volumes,
# then quit Docker Desktop if no other containers are running.
#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$envFile = Join-Path $root ".env"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "docker was not found on PATH. Install Docker Desktop and start it first."
    exit 1
}

# cmd.exe keeps the daemon-down error text from becoming a terminating error under $ErrorActionPreference = Stop.
& cmd.exe /c "docker info >nul 2>&1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker is not running; nothing to stop."
    exit 0
}

$composeArgs = @(
    "compose",
    "--project-directory", $root,
    "-f", (Join-Path $root "docker-compose.yml"),
    "-f", (Join-Path $root "docker-compose.override.yml"),
    "--env-file", $envFile,
    "down"
)

& docker @composeArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Quitting Docker Desktop stops every container, so leave it open if anything else is still running.
$others = @(& docker ps -q)
if ($others.Count -gt 0) {
    Write-Host "Other containers are still running; leaving Docker Desktop open."
    exit 0
}

Write-Host "Stack stopped. Closing Docker Desktop."
& cmd.exe /c "docker desktop stop >nul 2>&1"
if ($LASTEXITCODE -ne 0) {
    # Older Docker Desktop builds have no `docker desktop stop`.
    Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue | Stop-Process
}
exit 0
