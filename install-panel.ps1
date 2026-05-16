<#
.SYNOPSIS
    Installs the Pterodactyl Game Panel on Windows using Docker.
.DESCRIPTION
    This script automates the deployment of the Pterodactyl Panel (v1.12.2+)
    on Windows using Docker Desktop. It handles prerequisite checks, Docker
    Compose setup, database initialization, admin account creation, and egg
    installation.
.PARAMETER SkipChecks
    Skip prerequisite verification (Docker, Git).
.PARAMETER AutoYes
    Automatically answer yes to all prompts.
.EXAMPLE
    .\install-panel.ps1
    .\install-panel.ps1 -AutoYes
#>

[CmdletBinding()]
param(
    [switch]$SkipChecks,
    [switch]$AutoYes
)

$ErrorActionPreference = "Stop"
$ScriptVersion = "1.0.0"
$PteroVersion = "v1.12.2"
$WingsVersion = "v1.12.1"

# --- Helper Functions ---

function Write-Banner {
    Clear-Host
    Write-Host @"

  ____  _        _____                     _                _   ___
 |  _ \| |      | ____|_ ____   _____  ___| |_   ___  __ _| | |__ \
 | |_) | |      |  _| | '_ \ \ / / _ \/ __| __| / __|/ _` | |   / /
 |  __/| |___   | |___| | | \ V /  __/\__ \ |_  \__ \ (_| | |  |_|
 |_|   |_____|  |_____|_| |_|\_/ \___||___/\__| |___/\__,_|_|  (_)

"@ -ForegroundColor Cyan
    Write-Host " Pterodactyl Panel Installer for Windows" -ForegroundColor Cyan
    Write-Host " Version $ScriptVersion | Panel $PteroVersion | Wings $WingsVersion" -ForegroundColor Gray
    Write-Host " As of: May 15, 2026" -ForegroundColor Gray
    Write-Host ""
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Confirm-Action {
    param([string]$Message)
    if ($AutoYes) { return $true }
    $response = Read-Host "$Message (y/N)"
    return $response -eq "y" -or $response -eq "Y"
}

function Test-Command {
    param([string]$Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

# --- Prerequisite Checks ---

function Test-Prerequisites {
    Write-Host "`n[1/8] Checking prerequisites..." -ForegroundColor Yellow

    $errors = @()

    if (-not (Test-Command docker)) {
        $errors += "Docker is not installed. Download Docker Desktop for Windows from:"
        $errors += "  https://docs.docker.com/desktop/install/windows-install/"
    } else {
        $dockerVersion = docker --version 2>$null
        Write-Host "  [OK] Docker: $dockerVersion" -ForegroundColor Green

        $dockerRunning = docker info 2>$null
        if (-not $?) {
            $errors += "Docker Desktop is installed but not running. Please start Docker Desktop."
        } else {
            Write-Host "  [OK] Docker daemon is running" -ForegroundColor Green
        }
    }

    if (-not (Test-Command git)) {
        $errors += "Git is not installed. Download from: https://git-scm.com/download/win"
    } else {
        $gitVersion = git --version 2>$null
        Write-Host "  [OK] Git: $gitVersion" -ForegroundColor Green
    }

    if (-not (Test-Command docker-compose) -and -not (Test-Command "docker compose")) {
        $errors += "Docker Compose is not available. Ensure Docker Desktop includes it."
    } else {
        Write-Host "  [OK] Docker Compose is available" -ForegroundColor Green
    }

    $wslInstalled = (Get-WmiObject -Class Win32_OptionalFeature -Filter "Name='Microsoft-Windows-Subsystem-Linux'" -ErrorAction SilentlyContinue) -or
                    (dism /online /get-featureinfo /featurename:Microsoft-Windows-Subsystem-Linux 2>$null | Select-String "Enabled")
    if ($wslInstalled) {
        Write-Host "  [OK] WSL2 is available" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] WSL2 is not detected (only needed for Wings, not the panel)" -ForegroundColor Yellow
    }

    if ($errors.Count -gt 0) {
        Write-Host "`nPrerequisite check FAILED:" -ForegroundColor Red
        foreach ($err in $errors) {
            Write-Host "  - $err" -ForegroundColor Red
        }
        if (-not $SkipChecks) {
            throw "Please install missing prerequisites and try again."
        }
        Write-Host "  (proceeding anyway due to -SkipChecks)" -ForegroundColor Yellow
    }

    Write-Host "  [DONE] All prerequisites satisfied" -ForegroundColor Green
}

# --- Environment Setup ---

function Setup-Environment {
    Write-Host "`n[2/8] Setting up environment..." -ForegroundColor Yellow

    # Check if .env exists, if not copy from example
    if (-not (Test-Path ".env")) {
        if (Test-Path ".env.example") {
            Copy-Item ".env.example" ".env"
            Write-Host "  [INFO] Created .env from .env.example" -ForegroundColor Yellow
            Write-Host "  [INFO] Please edit .env with your settings before proceeding." -ForegroundColor Yellow
            if (-not $AutoYes) {
                $continue = Confirm-Action "  Have you edited .env with your settings?"
                if (-not $continue) {
                    Write-Host "  [ABORT] Please edit .env first, then re-run this script." -ForegroundColor Red
                    exit 1
                }
            }
        } else {
            Write-Host "  [ERROR] .env.example not found!" -ForegroundColor Red
            throw "Missing .env.example"
        }
    } else {
        Write-Host "  [OK] .env file exists" -ForegroundColor Green
    }

    # Create data directories
    $dirs = @(
        "data/database",
        "data/panel/var",
        "data/panel/logs",
        "data/panel/nginx",
        "data/panel/certs",
        "data/wings",
        "eggs",
        "scripts"
    )

    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Host "  [OK] Created directory: $dir" -ForegroundColor Green
        }
    }
}

# --- Docker Setup ---

function Start-DockerStack {
    Write-Host "`n[3/8] Starting Docker services..." -ForegroundColor Yellow

    # Pull latest images
    Write-Host "  [INFO] Pulling Docker images (this may take a while)..." -ForegroundColor Yellow
    docker compose pull
    if (-not $?) {
        Write-Host "  [INFO] Trying 'docker-compose' instead..." -ForegroundColor Yellow
        docker-compose pull
    }

    # Start containers
    Write-Host "  [INFO] Starting containers..." -ForegroundColor Yellow
    docker compose up -d
    if (-not $?) {
        docker-compose up -d
    }

    if ($?) {
        Write-Host "  [OK] All containers started" -ForegroundColor Green
    } else {
        throw "Failed to start Docker containers. Check docker-compose logs."
    }

    # Wait for panel to be ready
    Write-Host "  [INFO] Waiting for panel to be ready..." -ForegroundColor Yellow
    $maxRetries = 30
    $retryCount = 0
    do {
        Start-Sleep -Seconds 2
        $response = Invoke-WebRequest -Uri "http://localhost/api/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
        $retryCount++
    } while ($response.StatusCode -ne 200 -and $retryCount -lt $maxRetries)

    if ($response.StatusCode -eq 200) {
        Write-Host "  [OK] Panel is responding" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Panel may still be starting up. Check with: docker compose logs panel" -ForegroundColor Yellow
    }
}

# --- Panel Initialization ---

function Initialize-Panel {
    Write-Host "`n[4/8] Initializing panel..." -ForegroundColor Yellow

    # Generate app key
    Write-Host "  [INFO] Generating application key..." -ForegroundColor Yellow
    docker compose exec -T panel php artisan key:generate --force
    if (-not $?) {
        docker-compose exec -T panel php artisan key:generate --force
    }
    Write-Host "  [OK] Application key generated" -ForegroundColor Green

    # Run migrations
    Write-Host "  [INFO] Running database migrations..." -ForegroundColor Yellow
    docker compose exec -T panel php artisan migrate --seed --force
    if (-not $?) {
        docker-compose exec -T panel php artisan migrate --seed --force
    }
    Write-Host "  [OK] Database migrations complete" -ForegroundColor Green

    # Create admin user
    Write-Host "`n[5/8] Creating admin user..." -ForegroundColor Yellow
    $adminEmail = ""
    $adminUser = ""
    $adminPass = ""

    if ($AutoYes) {
        $adminEmail = "admin@example.com"
        $adminUser = "admin"
        $adminPass = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 24 | % {[char]$_})
    } else {
        $adminEmail = Read-Host "  Admin email"
        $adminUser = Read-Host "  Admin username"
        $adminPass = Read-Host -AsSecureString "  Admin password (leave blank for auto-generated)"
        if (-not $adminPass) {
            $adminPass = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 24 | % {[char]$_})
            Write-Host "  Auto-generated password: $adminPass" -ForegroundColor Yellow
        } else {
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($adminPass)
            $adminPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        }
    }

    docker compose exec -T panel php artisan p:user:make `
        --email="$adminEmail" `
        --username="$adminUser" `
        --name="Administrator" `
        --password="$adminPass" `
        --admin=1
    if (-not $?) {
        docker-compose exec -T panel php artisan p:user:make `
            --email="$adminEmail" `
            --username="$adminUser" `
            --name="Administrator" `
            --password="$adminPass" `
            --admin=1
    }

    Write-Host "  [OK] Admin user created" -ForegroundColor Green
    Write-Host "  Email:    $adminEmail" -ForegroundColor Cyan
    Write-Host "  Username: $adminUser" -ForegroundColor Cyan
    Write-Host "  Password: $adminPass" -ForegroundColor Cyan
    Write-Host "  SAVE THESE CREDENTIALS!" -ForegroundColor Red
}

# --- Egg Imports ---

function Import-Eggs {
    Write-Host "`n[6/8] Importing game server eggs..." -ForegroundColor Yellow

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

    foreach ($egg in $eggSources) {
        $eggFile = Join-Path "eggs" "$($egg.Name -replace '[^a-zA-Z0-9]', '-').json"
        if (Test-Path $eggFile) {
            Write-Host "  [OK] $($egg.Name) egg already exists" -ForegroundColor Green
            continue
        }

        Write-Host "  [INFO] Downloading $($egg.Name) egg..." -ForegroundColor Yellow

        try {
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($egg.Url, $eggFile)
            Write-Host "  [OK] $($egg.Name) egg saved" -ForegroundColor Green
        } catch {
            Write-Host "  [WARN] Failed to download $($egg.Name): $_" -ForegroundColor Yellow
        }
    }
}

# --- Wings Setup ---

function Setup-Wings {
    Write-Host "`n[7/8] Setting up Wings daemon..." -ForegroundColor Yellow
    Write-Host "  [INFO] Wings requires WSL2 with Ubuntu or Debian." -ForegroundColor Yellow
    Write-Host "  [INFO] The install-wings.ps1 script handles WSL2 Wings setup." -ForegroundColor Yellow
    Write-Host "  [SKIP] Run .\install-wings.ps1 separately after panel installation." -ForegroundColor Yellow
}

# --- Summary ---

function Show-Summary {
    Write-Host "`n[8/8] Installation Summary" -ForegroundColor Yellow
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host "  Pterodactyl Panel:     http://localhost" -ForegroundColor Green
    Write-Host "  Panel Version:         $PteroVersion" -ForegroundColor Gray
    Write-Host "  Wings Version:         $WingsVersion" -ForegroundColor Gray
    Write-Host "  Data Directory:        $PWD\data" -ForegroundColor Gray
    Write-Host "  Egg Directory:         $PWD\eggs" -ForegroundColor Gray
    Write-Host "" -ForegroundColor Gray
    Write-Host "  Next Steps:" -ForegroundColor Yellow
    Write-Host "    1. Configure Wings:     .\install-wings.ps1" -ForegroundColor Yellow
    Write-Host "    2. Update everything:   .\update-all.ps1" -ForegroundColor Yellow
    Write-Host "    3. Manage panel:        docker compose logs panel -f" -ForegroundColor Yellow
    Write-Host "    4. Restart stack:       docker compose restart" -ForegroundColor Yellow
    Write-Host "    5. Stop stack:          docker compose down" -ForegroundColor Yellow
    Write-Host "=" * 60 -ForegroundColor Cyan
}

# --- Main Execution ---

function Main {
    Write-Banner

    # Check admin rights (not strictly required for Docker Desktop but helpful)
    if (-not (Test-Administrator)) {
        Write-Host "  [WARN] Not running as Administrator. Some operations may fail." -ForegroundColor Yellow
        if (-not (Confirm-Action "  Continue anyway?")) {
            exit 1
        }
    }

    try {
        # Change to script directory
        Set-Location $PSScriptRoot

        Test-Prerequisites
        Setup-Environment
        Start-DockerStack
        Initialize-Panel
        Import-Eggs
        Setup-Wings
        Show-Summary

        Write-Host "`n  Installation complete!" -ForegroundColor Green
        Write-Host "  Open http://localhost in your browser to access the panel.`n" -ForegroundColor Green
    } catch {
        Write-Host "`n  [FATAL] Installation failed:" -ForegroundColor Red
        Write-Host "  $_" -ForegroundColor Red
        Write-Host "`n  Check docker compose logs for details:" -ForegroundColor Yellow
        Write-Host "  docker compose logs panel" -ForegroundColor Yellow
        exit 1
    }
}

Main
