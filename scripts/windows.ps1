# Local Docker test on Windows. Same compose files as scripts/dc.sh.
# Does not clone upstream, download client data, or build map_extractor.exe.
#Requires -Version 5.1
$ErrorActionPreference = "Stop"
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function Fail([string]$message) {
    Write-Host $message
    exit 1
}

function Get-EnvValue([string]$name) {
    $value = $null
    foreach ($line in Get-Content -LiteralPath (Join-Path $root ".env")) {
        if ($line -match "^\s*#") { continue }
        if ($line -match ("^\s*" + [regex]::Escape($name) + "=(.*)$")) {
            $value = $Matches[1].Trim()
            if ($value.Length -ge 2) {
                $quote = $value.Substring(0, 1)
                if (($quote -eq '"' -or $quote -eq "'") -and $value.EndsWith($quote)) {
                    $value = $value.Substring(1, $value.Length - 2)
                }
            }
        }
    }
    return $value
}

function Test-NonEmptyDir([string]$path) {
    if (-not (Test-Path -LiteralPath $path -PathType Container)) {
        return $false
    }
    $item = Get-ChildItem -LiteralPath $path -Force | Select-Object -First 1
    return $null -ne $item
}

if (-not (Test-Path -LiteralPath (Join-Path $root "CMakeLists.txt") -PathType Leaf) -or
    -not (Test-Path -LiteralPath (Join-Path $root "docker-compose.yml") -PathType Leaf)) {
    Fail "Missing server source (CMakeLists.txt or docker-compose.yml). Clone Milzstream/azeroth-solo; do not expect a separate core checkout."
}

foreach ($name in @("mod-playerbots", "mod-individual-progression", "mod-ollama-chat")) {
    $moduleSrc = Join-Path (Join-Path (Join-Path $root "modules") $name) "src"
    if (-not (Test-Path -LiteralPath $moduleSrc -PathType Container)) {
        Fail "Missing modules/$name source."
    }
}

$sqlDest = Join-Path (Join-Path (Join-Path (Join-Path $root "data") "sql") "custom") "db_auth"
New-Item -ItemType Directory -Force -Path $sqlDest | Out-Null
Copy-Item -Force -Path (Join-Path (Join-Path (Join-Path $root "sql") "db_auth") "*.sql") -Destination $sqlDest
Write-Host "Copied realm-name SQL into data/sql/custom/db_auth (applied by db-import)."

$envFile = Join-Path $root ".env"
$envExample = Join-Path $root ".env.example"
if (-not (Test-Path -LiteralPath $envFile -PathType Leaf)) {
    if (-not (Test-Path -LiteralPath $envExample -PathType Leaf)) {
        Fail "Missing .env.example."
    }
    Copy-Item -LiteralPath $envExample -Destination $envFile
    Fail "Copied .env.example to .env. Set DOCKER_DB_ROOT_PASSWORD in .env (replace change-me) and put your extracted dbc, maps, vmaps, and mmaps directories in client-data/, then run this script again."
}

$password = Get-EnvValue "DOCKER_DB_ROOT_PASSWORD"
if ([string]::IsNullOrWhiteSpace($password) -or $password -eq "change-me") {
    Fail "Set DOCKER_DB_ROOT_PASSWORD in .env before the first start. Do not leave it empty or as change-me. If the variable is empty, docker-compose.yml uses password."
}

$dataRel = Get-EnvValue "DOCKER_VOL_DATA"
if ([string]::IsNullOrWhiteSpace($dataRel)) {
    $dataRel = "./client-data"
}
if ([System.IO.Path]::IsPathRooted($dataRel)) {
    $dataDir = $dataRel
} else {
    $dataDir = Join-Path $root ($dataRel -replace '^[.][/\\]', '')
}

$missing = @()
foreach ($dirName in @("dbc", "maps", "vmaps", "mmaps")) {
    if (-not (Test-NonEmptyDir (Join-Path $dataDir $dirName))) {
        $missing += $dirName
    }
}
if ($missing.Count -gt 0) {
    Fail ("Missing extracted client data in " + $dataDir + ": " + ($missing -join ", ") + ". Copy dbc, maps, vmaps, mmaps, and Cameras there (DOCKER_VOL_DATA). This setup does not download them. map_extractor.exe is not in the repo.")
}
if (-not (Test-NonEmptyDir (Join-Path $dataDir "Cameras"))) {
    Write-Host "Note: Cameras is empty. map_extractor also writes Cameras. Recommended, not required to start."
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Fail "docker was not found on PATH. Install Docker Desktop, start it, and open a new PowerShell window in this repo."
}

$composeArgs = @(
    "compose",
    "--project-directory", $root,
    "-f", (Join-Path $root "docker-compose.yml"),
    "-f", (Join-Path $root "docker-compose.override.yml"),
    "--env-file", $envFile
)

Write-Host "docker compose build"
& docker @composeArgs build
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "docker compose up -d"
& docker @composeArgs up -d
exit $LASTEXITCODE
