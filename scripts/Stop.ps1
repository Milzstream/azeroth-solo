# Stop the local AzerothCore Docker Compose stack without deleting its volumes.
#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$envFile = Join-Path $root ".env"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "docker was not found on PATH. Install Docker Desktop and start it first."
    exit 1
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
exit $LASTEXITCODE