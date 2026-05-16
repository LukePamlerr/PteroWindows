<#
.SYNOPSIS
    Installs Pterodactyl Wings daemon on Windows via WSL2.
.DESCRIPTION
    Wings is the backend daemon that runs game server containers. It requires
    Linux (WSL2). This script automates: WSL2 Ubuntu installation, Docker
    Engine inside WSL2, Wings binary download, and service configuration.
.PARAMETER AutoYes
    Automatically answer yes to all prompts.
.PARAMETER WslDistro
    WSL2 distribution name (default: Ubuntu-22.04).
.EXAMPLE
    .\install-wings.ps1
    .\install-wings.ps1 -AutoYes -WslDistro Ubuntu-24.04
#>

[CmdletBinding()]
param(
    [switch]$AutoYes,
    [string]$WslDistro = "Ubuntu-22.04"
)

$ErrorActionPreference = "Stop"
$ScriptVersion = "1.0.0"

# --- Helper Functions ---

function Write-Banner {
    Write-Host @"

  __        ___ _ __   __ _ _ __ ___   ___
  \ \      / _ \ '_ \ / _` | '_ ` _ \ / _ \
   \ \ /\ / / __/ | | | (_| | | | | | |  __/
    \ V  V / \___|_| |_|\__,_|_| |_| |_|\___|

  Wings Daemon Installer for Windows (via WSL2)
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

# --- Prerequisites ---

function Test-Prerequisites {
    Write-Host "[1/6] Checking prerequisites..." -ForegroundColor Yellow

    # Check WSL
    $wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if (-not $wsl) {
        throw "WSL is not installed. Run: wsl --install (as Administrator)"
    }
    Write-Host "  [OK] WSL is available" -ForegroundColor Green

    # Check WSL2 default
    $wslStatus = wsl --status 2>&1
    if ($wslStatus -match "Default Version: 2") {
        Write-Host "  [OK] WSL2 is the default version" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] WSL2 may not be the default. Setting WSL2 as default..." -ForegroundColor Yellow
        wsl --set-default-version 2
    }

    # Check if distro exists
    $distros = wsl --list --quiet 2>&1
    if ($distros -match [regex]::Escape($WslDistro)) {
        Write-Host "  [OK] WSL distro '$WslDistro' exists" -ForegroundColor Green
    } else {
        Write-Host "  [INFO] WSL distro '$WslDistro' not found. Installing..." -ForegroundColor Yellow
        wsl --install -d $WslDistro
        if (-not $?) {
            throw "Failed to install WSL distro '$WslDistro'"
        }
        Write-Host "  [OK] '$WslDistro' installed" -ForegroundColor Green
    }
}

# --- Docker in WSL ---

function Install-DockerInWsl {
    Write-Host "[2/6] Installing Docker Engine in WSL..." -ForegroundColor Yellow

    $dockerCheck = wsl -d $WslDistro -- which docker 2>&1
    if ($dockerCheck -match "/usr/bin/docker") {
        Write-Host "  [OK] Docker is already installed in WSL" -ForegroundColor Green
        return
    }

    Write-Host "  [INFO] Installing Docker Engine in WSL (this takes a moment)..." -ForegroundColor Yellow

    $installScript = @'
set -e
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
sudo usermod -aG docker $USER
rm get-docker.sh
'@

    wsl -d $WslDistro -- bash -c $installScript
    if (-not $?) {
        throw "Failed to install Docker Engine in WSL"
    }

    Write-Host "  [OK] Docker Engine installed in WSL" -ForegroundColor Green
    Write-Host "  [INFO] Start Docker with: wsl -d $WslDistro -- sudo service docker start" -ForegroundColor Yellow
}

# --- Install Wings ---

function Install-Wings {
    Write-Host "[3/6] Installing Wings binary..." -ForegroundColor Yellow

    $wingsCheck = wsl -d $WslDistro -- which wings 2>&1
    if ($wingsCheck -match "/usr/local/bin/wings") {
        Write-Host "  [OK] Wings is already installed" -ForegroundColor Green
        return
    }

    Write-Host "  [INFO] Downloading latest Wings release..." -ForegroundColor Yellow

    $installScript = @'
set -e
mkdir -p /etc/pterodactyl
curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64"
chmod +x /usr/local/bin/wings
'@

    wsl -d $WslDistro -- bash -c $installScript
    if (-not $?) {
        throw "Failed to install Wings binary"
    }

    Write-Host "  [OK] Wings binary installed" -ForegroundColor Green
}

# --- Configure Wings Service ---

function Configure-WingsService {
    Write-Host "[4/6] Configuring Wings as a system service..." -ForegroundColor Yellow

    $serviceScript = @'
cat > /tmp/wings-install.sh << 'SHEOF'
#!/bin/bash
# Wings systemd service
cat > /etc/systemd/system/wings.service << 'EOF'
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
ExecStart=/usr/local/bin/wings
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable wings
SHEOF
chmod +x /tmp/wings-install.sh
bash /tmp/wings-install.sh
'@

    wsl -d $WslDistro -- bash -c $serviceScript
    Write-Host "  [OK] Wings service configured" -ForegroundColor Green
}

# --- Generate Config ---

function Generate-WingsConfig {
    Write-Host "[5/6] Generating Wings configuration..." -ForegroundColor Yellow

    $configPath = Join-Path $PSScriptRoot "data\wings\config.yml"

    if (Test-Path $configPath) {
        Write-Host "  [OK] Wings config already exists at $configPath" -ForegroundColor Green
    } else {
        Write-Host "  [INFO] A blank config.yml template will be created." -ForegroundColor Yellow
        Write-Host "  [INFO] You MUST configure it from the Panel admin interface." -ForegroundColor Yellow
        Write-Host "  [INFO] Steps:" -ForegroundColor Yellow
        Write-Host "    1. Log into the panel at http://localhost" -ForegroundColor Yellow
        Write-Host "    2. Go to Admin > Nodes > Create New" -ForegroundColor Yellow
        Write-Host "    3. Fill in the details (use 127.0.0.1 for FQDN if local)" -ForegroundColor Yellow
        Write-Host "    4. After creation, go to the Node > Configuration tab" -ForegroundColor Yellow
        Write-Host "    5. Copy the config and save as data/wings/config.yml" -ForegroundColor Yellow

        $configTemplate = @'
# Pterodactyl Wings Configuration
# Generated by PteroWindows Installer
# Replace this with the config from Admin > Nodes > [Your Node] > Configuration

debug: false
uuid: CHANGE-ME
token_id: CHANGE-ME
token: CHANGE-ME
api:
  host: 127.0.0.1
  port: 8080
  ssl:
    enabled: false
    certificate: /etc/pterodactyl/cert.pem
    key: /etc/pterodactyl/key.pem
  upload_limit: 100
system:
  data: /etc/pterodactyl
  sftp:
    bind_port: 2022
allowed_mounts: []
remote: http://localhost
'@
        $configTemplate | Out-File -FilePath $configPath -Encoding utf8
        Write-Host "  [WARN] Template created. You MUST replace with real config from panel!" -ForegroundColor Yellow
    }
}

# --- Start Wings ---

function Start-WingsDaemon {
    Write-Host "[6/6] Starting Wings daemon..." -ForegroundColor Yellow

    Write-Host "  [INFO] Copying config to WSL..." -ForegroundColor Yellow
    $configPath = Join-Path $PSScriptRoot "data\wings\config.yml"
    if (Test-Path $configPath) {
        wsl -d $WslDistro -- bash -c "mkdir -p /etc/pterodactyl"
        wsl -d $WslDistro -- cp "/mnt/c/Users/$env:USERNAME/Downloads/PteroWindows/data/wings/config.yml" /etc/pterodactyl/config.yml 2>$null
        # Alternative: copy via PowerShell
        $wslConfigPath = "\\wsl.localhost\$WslDistro\etc\pterodactyl\config.yml"
        try {
            Copy-Item $configPath $wslConfigPath -Force -ErrorAction SilentlyContinue
            Write-Host "  [OK] Config copied to WSL" -ForegroundColor Green
        } catch {
            Write-Host "  [WARN] Could not copy config to WSL path. Do this manually:" -ForegroundColor Yellow
            Write-Host "    wsl -d $WslDistro -- cp /mnt/c/Users/$env:USERNAME/Downloads/PteroWindows/data/wings/config.yml /etc/pterodactyl/config.yml" -ForegroundColor Yellow
        }
    }

    Write-Host "  [INFO] Starting Wings (via Docker in WSL)..." -ForegroundColor Yellow
    wsl -d $WslDistro -- sudo service docker start 2>$null
    wsl -d $WslDistro -- sudo systemctl start wings 2>$null

    Write-Host "  [INFO] Check Wings status:" -ForegroundColor Yellow
    Write-Host "    wsl -d $WslDistro -- sudo systemctl status wings" -ForegroundColor Yellow
    Write-Host "    wsl -d $WslDistro -- sudo journalctl -u wings -f" -ForegroundColor Yellow
}

# --- Main ---

function Main {
    Write-Banner

    if (-not (Confirm-Action "This will install Wings in WSL2. Continue?")) {
        exit 0
    }

    try {
        Set-Location $PSScriptRoot
        Test-Prerequisites
        Install-DockerInWsl
        Install-Wings
        Configure-WingsService
        Generate-WingsConfig
        Start-WingsDaemon

        Write-Host "`n  Wings installation complete!" -ForegroundColor Green
        Write-Host "  Make sure to:" -ForegroundColor Yellow
        Write-Host "    1. Create a Node in the panel (Admin > Nodes)" -ForegroundColor Yellow
        Write-Host "    2. Copy the config from Admin > Nodes > [Node] > Configuration" -ForegroundColor Yellow
        Write-Host "    3. Save it to data/wings/config.yml" -ForegroundColor Yellow
        Write-Host "    4. Restart Wings: wsl -d $WslDistro -- sudo systemctl restart wings" -ForegroundColor Yellow
    } catch {
        Write-Host "`n  [FATAL] Wings installation failed:" -ForegroundColor Red
        Write-Host "  $_" -ForegroundColor Red
        exit 1
    }
}

Main
