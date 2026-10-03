# Local Docker test on Windows, after the extractor tools are on disk.
# Default path downloads the windows-extractor-tools Actions artifact.
# -LocalBuild runs ./acore.sh compiler build with CAPPS_BUILD=none and
# CTOOLS_BUILD=maps-only (apps/ci/ci-conf-tools.sh). PCH stays at the default.
# Does not clone upstream or download client data.
#Requires -Version 5.1
param(
    [switch]$LocalBuild
)
$ErrorActionPreference = "Stop"
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$toolNames = @("map_extractor.exe", "vmap4_extractor.exe", "vmap4_assembler.exe", "mmaps_generator.exe")

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

function ConvertTo-GitBashPath([string]$path) {
    $full = [System.IO.Path]::GetFullPath($path)
    if ($full -match "^([A-Za-z]):\\(.*)$") {
        return "/" + $Matches[1].ToLower() + "/" + ($Matches[2] -replace "\\", "/")
    }
    return ($full -replace "\\", "/")
}

function Show-ExtractorTools([string]$dir) {
    $missing = @()
    foreach ($name in $toolNames) {
        if (-not (Test-Path -LiteralPath (Join-Path $dir $name) -PathType Leaf)) {
            $missing += $name
        }
    }
    if ($missing.Count -gt 0) {
        Fail ("Extractor tools are incomplete in " + $dir + ": " + ($missing -join ", "))
    }
    Write-Host ""
    Write-Host "Extractor tools:"
    foreach ($name in $toolNames) {
        Write-Host (Join-Path $dir $name)
    }
    $extra = @(Get-ChildItem -LiteralPath $dir -File | Where-Object { $toolNames -notcontains $_.Name })
    if ($extra.Count -gt 0) {
        Write-Host "Also in that folder (copy these with the exes):"
        foreach ($file in $extra) {
            Write-Host $file.FullName
        }
    }
    Write-Host ""
    Write-Host "Copy these files into your Wrath 3.3.5a client directory (the folder that contains Wow.exe and Data)."
    Write-Host "Then, in that directory: map_extractor.exe; vmap4_extractor.exe; vmap4_assembler.exe Buildings vmaps; mmaps_generator.exe."
    Write-Host "apps\extractor\extractor.bat is that menu. It does not compile the tools."
    Write-Host "mmaps_generator.exe reads mmaps-config.yaml from the same directory. Do not commit dbc, maps, vmaps, mmaps, or Cameras."
}

function Find-ExtractorDir([string[]]$candidates) {
    foreach ($dir in $candidates) {
        if (Test-Path -LiteralPath (Join-Path $dir "map_extractor.exe") -PathType Leaf) {
            return $dir
        }
    }
    return $null
}

function Write-LocalBuildCommand {
    Write-Host "Local build, from Git Bash in this clone. These are the apps/ci/ci-conf-tools.sh settings. ./acore.sh compiler build is the same entry point as .github/workflows/windows_build.yml. conf/dist/config.sh reads CAPPS_BUILD and CTOOLS_BUILD from the environment."
    Write-Host "  export CAPPS_BUILD=none"
    Write-Host "  export CTOOLS_BUILD=maps-only"
    Write-Host "  ./acore.sh compiler build"
    Write-Host "That needs Visual Studio, Boost (BOOST_ROOT), a MySQL client library CMake can find, and OpenSSL (OPENSSL_ROOT_DIR). It builds the four extractor targets only (APPS_BUILD=none). On Git Bash, OSTYPE is cygwin, so cmake --install is skipped and the exes stay in var\build\obj\bin\Release\."
    Write-Host "The Windows core installation wiki does not give a cmake command line. It sets TOOLS_BUILD to all and builds ALL_BUILD (the whole server), RelWithDebInfo, x64."
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

$toolDir = $null
if ($LocalBuild) {
    $bash = $null
    $bashCmd = Get-Command bash -ErrorAction SilentlyContinue
    if ($bashCmd) {
        $bash = $bashCmd.Source
    } else {
        $gitBash = @()
        if ($env:ProgramFiles) {
            $gitBash += (Join-Path $env:ProgramFiles "Git\bin\bash.exe")
        }
        $pfx86 = [Environment]::GetEnvironmentVariable("ProgramFiles(x86)")
        if ($pfx86) {
            $gitBash += (Join-Path $pfx86 "Git\bin\bash.exe")
        }
        foreach ($candidate in $gitBash) {
            if ($candidate -and (Test-Path -LiteralPath $candidate)) {
                $bash = $candidate
                break
            }
        }
    }
    if (-not $bash) {
        Write-LocalBuildCommand
        Fail "bash was not found. Install Git for Windows, or run this script without -LocalBuild to download the windows-extractor-tools artifact."
    }
    $bashRoot = (ConvertTo-GitBashPath $root) -replace "'", "'\''"
    Write-Host "Building extractor tools with ./acore.sh compiler build (CAPPS_BUILD=none CTOOLS_BUILD=maps-only)."
    & $bash -c "cd '$bashRoot' && export CAPPS_BUILD=none && export CTOOLS_BUILD=maps-only && ./acore.sh compiler build"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $toolDir = Find-ExtractorDir @(
        (Join-Path $root "var\build\obj\bin\Release"),
        (Join-Path $root "var\build\obj\bin\RelWithDebInfo"),
        (Join-Path $root "env\dist\bin"),
        (Join-Path $root "env\dist")
    )
    if (-not $toolDir) {
        Fail "acore.sh finished but map_extractor.exe was not under var\build\obj\bin\Release, var\build\obj\bin\RelWithDebInfo, or env\dist."
    }
    Write-Host "Local build does not copy OpenSSL DLLs. The Windows core installation page says to copy libcrypto-3-x64.dll and libssl-3-x64.dll from the OpenSSL bin directory next to the executables."
} else {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-LocalBuildCommand
        Fail "gh was not found on PATH. Install GitHub CLI and run gh auth login, then run this script again. Or pass -LocalBuild if Visual Studio is already installed."
    }
    $json = & gh run list --repo Milzstream/azeroth-solo --workflow windows-extractor-tools.yml --branch main --status success --limit 1 --json databaseId,url,headSha
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $runs = @()
    if (-not [string]::IsNullOrWhiteSpace($json)) {
        $parsed = $json | ConvertFrom-Json
        if ($null -ne $parsed) {
            $runs = @($parsed)
        }
    }
    if ($runs.Count -lt 1 -or -not $runs[0].databaseId) {
        Write-LocalBuildCommand
        Fail "No successful windows-extractor-tools run on main yet. https://github.com/Milzstream/azeroth-solo/actions/workflows/windows-extractor-tools.yml"
    }
    $runId = [string]$runs[0].databaseId
    $download = Join-Path (Join-Path (Join-Path $root "env") "dist") "bin-download"
    if (Test-Path -LiteralPath $download) {
        Remove-Item -LiteralPath $download -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $download | Out-Null
    Write-Host ("Downloading artifact windows-extractor-tools from run " + $runId)
    & gh run download $runId --repo Milzstream/azeroth-solo --name windows-extractor-tools --dir $download
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $found = Get-ChildItem -LiteralPath $download -Recurse -Filter map_extractor.exe | Select-Object -First 1
    if (-not $found) {
        Fail "The artifact did not contain map_extractor.exe."
    }
    $toolDir = Join-Path (Join-Path (Join-Path $root "env") "dist") "bin"
    New-Item -ItemType Directory -Force -Path $toolDir | Out-Null
    Copy-Item -Force -Path (Join-Path $found.Directory.FullName "*") -Destination $toolDir
    Remove-Item -LiteralPath $download -Recurse -Force
    Write-Host ("Downloaded windows-extractor-tools from " + $runs[0].url + " (commit " + $runs[0].headSha + ")")
}

Show-ExtractorTools $toolDir

$envFile = Join-Path $root ".env"
$envExample = Join-Path $root ".env.example"
$dataRel = $null
if (Test-Path -LiteralPath $envFile -PathType Leaf) {
    $dataRel = Get-EnvValue "DOCKER_VOL_DATA"
}
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
    Write-Host ("Docker was not started. Missing extracted client data in " + $dataDir + ": " + ($missing -join ", ") + ".")
    Write-Host "After extraction, copy dbc, maps, vmaps, mmaps, and Cameras into that directory (DOCKER_VOL_DATA). Do not put them under data\."
    if (-not (Test-Path -LiteralPath $envFile -PathType Leaf)) {
        Write-Host "Before the Docker run, copy .env.example to .env and set DOCKER_DB_ROOT_PASSWORD (replace change-me)."
    }
    Write-Host "Run this script again to start Docker. This repo does not download client data."
    exit 0
}
if (-not (Test-NonEmptyDir (Join-Path $dataDir "Cameras"))) {
    Write-Host "Note: Cameras is empty. map_extractor also writes Cameras. Recommended, not required to start."
}

if (-not (Test-Path -LiteralPath $envFile -PathType Leaf)) {
    if (-not (Test-Path -LiteralPath $envExample -PathType Leaf)) {
        Fail "Missing .env.example."
    }
    Copy-Item -LiteralPath $envExample -Destination $envFile
    Fail "Copied .env.example to .env. Set DOCKER_DB_ROOT_PASSWORD in .env (replace change-me) and run this script again."
}

$password = Get-EnvValue "DOCKER_DB_ROOT_PASSWORD"
if ([string]::IsNullOrWhiteSpace($password) -or $password -eq "change-me") {
    Fail "Set DOCKER_DB_ROOT_PASSWORD in .env before the first start. Do not leave it empty or as change-me. If the variable is empty, docker-compose.yml uses password."
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
