<#
.SYNOPSIS
    Updates Pterodactyl Panel, Wings, and eggs to the latest versions.
.DESCRIPTION
    This script pulls the latest Docker images for the panel, updates
    Wings in WSL2, and refreshes egg definitions from the community repos.
.PARAMETER SkipPanel
    Skip panel update.
.PARAMETER SkipWings
    Skip Wings update.
.PARAMETER SkipEggs
    Skip egg update.
.PARAMETER AutoYes
    Automatically confirm all prompts.
.EXAMPLE
    .\update-all.ps1
    .\update-all.ps1 -SkipWings
#>

[CmdletBinding()]
param(
    [switch]$SkipPanel,
    [switch]$SkipWings,
    [switch]$SkipEggs,
    [switch]$AutoYes
)

$ErrorActionPreference = "Stop"
$ScriptVersion = "1.0.0"

function Write-Banner {
    Clear-Host
    Write-Host @"
  _   _ ____  _   _ _____    __     ____
 | | | |  _ \| | | |_   _|   \ \   / / |
 | | | | |_) | | | | | |_____ \ \ / /| |
 | |_| |  __/| |_| | | |_____| \ V / | |___
  \___/|_|    \___/  |_|       \_/  |_____|

  Auto-Updater for PteroWindows
  Version $ScriptVersion
"@ -ForegroundColor Cyan
    Write-Host ""
}

function Confirm-Action {
    param([string]$Message)
    if ($AutoYes) { return $true }
    $response = Read-Host "$Message (y/N)"
    return $response -eq "y" -or $response -eq "Y"
}

function Update-Panel {
    Write-Host "[1/3] Updating Pterodactyl Panel..." -ForegroundColor Yellow

    try {
        Set-Location $PSScriptRoot

        Write-Host "  [INFO] Pulling latest panel Docker image..." -ForegroundColor Yellow
        docker compose pull panel
        if (-not $?) {
            docker-compose pull panel
        }

        Write-Host "  [INFO] Recreating panel container..." -ForegroundColor Yellow
        docker compose up -d --force-recreate panel
        if (-not $?) {
            docker-compose up -d --force-recreate panel
        }

        Write-Host "  [INFO] Running database migrations..." -ForegroundColor Yellow
        docker compose exec -T panel php artisan migrate --seed --force
        if (-not $?) {
            docker-compose exec -T panel php artisan migrate --seed --force
        }

        Write-Host "  [INFO] Clearing caches..." -ForegroundColor Yellow
        docker compose exec -T panel php artisan view:clear
        docker compose exec -T panel php artisan config:clear

        Write-Host "  [OK] Panel updated successfully" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] Panel update failed: $_" -ForegroundColor Yellow
    }
}

function Update-Wings {
    Write-Host "[2/3] Updating Wings daemon..." -ForegroundColor Yellow

    try {
        $wslDistro = "Ubuntu-22.04"

        Write-Host "  [INFO] Checking for WSL..." -ForegroundColor Yellow
        $distros = wsl --list --quiet 2>&1
        if ($distros -match "Ubuntu") {
            $wslDistro = ($distros | Select-String "Ubuntu").Line.Trim()
        }

        Write-Host "  [INFO] Downloading latest Wings binary..." -ForegroundColor Yellow
        wsl -d $wslDistro -- bash -c @'
set -e
curl -L -o /usr/local/bin/wings.new "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64"
chmod +x /usr/local/bin/wings.new
mv /usr/local/bin/wings.new /usr/local/bin/wings
'@

        Write-Host "  [INFO] Restarting Wings service..." -ForegroundColor Yellow
        wsl -d $wslDistro -- sudo systemctl restart wings

        Write-Host "  [OK] Wings updated successfully" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] Wings update failed: $_" -ForegroundColor Yellow
        Write-Host "  [INFO] Run .\install-wings.ps1 for a fresh Wings setup" -ForegroundColor Yellow
    }
}

function Update-Eggs {
    Write-Host "[3/3] Refreshing egg definitions..." -ForegroundColor Yellow

    try {
        $eggSources = @(
            @{ Name = "Paper"; Url = "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/paper/egg-paper.json" },
            @{ Name = "Spigot"; Url = "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/spigot/egg-spigot.json" },
            @{ Name = "Fabric"; Url = "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/fabric/egg-fabric.json" },
            @{ Name = "Forge"; Url = "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/forge/egg-forge.json" },
            @{ Name = "CurseForge"; Url = "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/curseforge/egg-curseforge-generic.json" },
            @{ Name = "BungeeCord"; Url = "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/bungeecord/egg-bungeecord.json" },
            @{ Name = "Purpur"; Url = "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/purpur/egg-purpur.json" },
            @{ Name = "Folia"; Url = "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/folia/egg-folia.json" }
        )

        $eggDir = Join-Path $PSScriptRoot "eggs"
        if (-not (Test-Path $eggDir)) {
            New-Item -ItemType Directory -Path $eggDir -Force | Out-Null
        }

        foreach ($egg in $eggSources) {
            Write-Host "  [INFO] Downloading $($egg.Name)..." -ForegroundColor Yellow
            $eggFile = Join-Path $eggDir "$($egg.Name).json"
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($egg.Url, $eggFile)
            Write-Host "  [OK] $($egg.Name) refreshed" -ForegroundColor Green
        }

        Write-Host "  [OK] All eggs updated" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] Egg update failed: $_" -ForegroundColor Yellow
    }
}

function Main {
    Write-Banner

    if (-not (Confirm-Action "Update all PteroWindows components?")) {
        Write-Host "Aborted." -ForegroundColor Red
        exit 0
    }

    Set-Location $PSScriptRoot

    if (-not $SkipPanel) { Update-Panel }
    if (-not $SkipWings) { Update-Wings }
    if (-not $SkipEggs) { Update-Eggs }

    Write-Host "`n  All updates complete!" -ForegroundColor Green
    Write-Host "  Panel:  http://localhost" -ForegroundColor Green
    Write-Host "  Wings:  wsl -d Ubuntu -- sudo systemctl status wings" -ForegroundColor Green
}

Main
