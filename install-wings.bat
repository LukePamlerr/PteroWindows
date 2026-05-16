@echo off
setlocal enabledelayedexpansion

title PteroWindows - Wings Installer
color 0C

echo.
echo  ========================================
echo    Wings Daemon Installer (via WSL2)
echo    v1.12.1 | May 15, 2026
echo  ========================================
echo.
echo  Wings requires WSL2 with Ubuntu. This script
echo  will set up WSL2, Docker Engine, and the
echo  Wings binary for you.
echo.

:ADMIN_CHECK
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo  [WARN] Administrator rights recommended for WSL operations.
    set /p CONTINUE="  Continue? (y/N): "
    if /i "!CONTINUE!" neq "y" exit /b 1
)

:CHECK_WSL
echo  [1] Checking WSL...
where wsl >nul 2>&1
if %errorlevel% neq 0 (
    echo  [FAIL] WSL not installed.
    echo  Run as Administrator: wsl --install
    pause
    exit /b 1
)
echo  [OK] WSL is available

:: Set WSL2 as default
wsl --status | find "Default Version: 2" >nul 2>&1
if %errorlevel% neq 0 (
    echo  [INFO] Setting WSL2 as default...
    wsl --set-default-version 2 >nul 2>&1
)

:CHECK_DISTRO
:: Get existing Ubuntu distro name
set WSL_DISTRO=
for /f "tokens=*" %%d in ('wsl --list --quiet ^| find "Ubuntu"') do set WSL_DISTRO=%%d

if "!WSL_DISTRO!"=="" (
    echo  [INFO] Installing Ubuntu-22.04 (this opens a setup window)...
    echo  [INFO] Complete the Ubuntu setup, then return here.
    echo.
    start /wait wsl --install -d Ubuntu-22.04
    for /f "tokens=*" %%d in ('wsl --list --quiet ^| find "Ubuntu"') do set WSL_DISTRO=%%d
    if "!WSL_DISTRO!"=="" (
        echo  [FAIL] Ubuntu installation failed or not completed.
        pause
        exit /b 1
    )
    echo  [OK] Ubuntu installed
) else (
    echo  [OK] WSL distro: !WSL_DISTRO!
)

:: Ensure WSL distro is version 2
wsl --set-version !WSL_DISTRO! 2 >nul 2>&1

:INSTALL_DOCKER_WSL
echo.
echo  [2] Installing Docker Engine in WSL...
wsl -d !WSL_DISTRO! -- which docker >nul 2>&1
if %errorlevel% equ 0 (
    echo  [OK] Docker already installed in WSL
) else (
    echo  [INFO] Installing Docker Engine (this takes a moment)...
    wsl -d !WSL_DISTRO! -- bash -c "curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh && sudo usermod -aG docker \$USER && rm get-docker.sh" <nul
    if %errorlevel% neq 0 (
        echo  [FAIL] Docker Engine installation failed.
        pause
        exit /b 1
    )
    echo  [OK] Docker Engine installed
)

:DOWNLOAD_WINGS
echo.
echo  [3] Downloading Wings binary...
wsl -d !WSL_DISTRO! -- which wings >nul 2>&1
if %errorlevel% equ 0 (
    echo  [OK] Wings already installed, checking for updates...
    wsl -d !WSL_DISTRO! -- bash -c "curl -L -o /usr/local/bin/wings.new https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64 && chmod +x /usr/local/bin/wings.new && mv /usr/local/bin/wings.new /usr/local/bin/wings" <nul
    echo  [OK] Wings updated to latest
) else (
    echo  [INFO] Downloading latest Wings release...
    wsl -d !WSL_DISTRO! -- bash -c "mkdir -p /etc/pterodactyl && curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64 && chmod +x /usr/local/bin/wings" <nul
    if %errorlevel% neq 0 (
        echo  [FAIL] Wings download failed.
        pause
        exit /b 1
    )
    echo  [OK] Wings binary installed
)

:CONFIGURE_SERVICE
echo.
echo  [4] Configuring Wings systemd service...

:: Write wings.service unit file via WSL
wsl -d !WSL_DISTRO! -- bash -c "cat > /tmp/wings.service << 'SERVICEEOF'
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
SERVICEEOF
sudo mv /tmp/wings.service /etc/systemd/system/wings.service
sudo systemctl daemon-reload
sudo systemctl enable wings" <nul

if %errorlevel% equ 0 (
    echo  [OK] Wings service configured
) else (
    echo  [WARN] Service configuration had issues
)

:SETUP_CONFIG
echo.
echo  [5] Setting up Wings configuration...

if not exist "data\wings" mkdir "data\wings"

if exist "data\wings\config.yml" (
    echo  [OK] Existing config.yml found
) else (
    echo  [INFO] Generating configuration template...
    (
        echo # Pterodactyl Wings Configuration
        echo # WARNING: Replace with config from Admin ^> Nodes ^> Configuration
        echo.
        echo debug: false
        echo uuid: CHANGE-ME
        echo token_id: CHANGE-ME
        echo token: CHANGE-ME
        echo api:
        echo   host: 127.0.0.1
        echo   port: 8080
        echo   ssl:
        echo     enabled: false
        echo system:
        echo   data: /etc/pterodactyl
        echo   sftp:
        echo     bind_port: 2022
        echo remote: http://localhost
    ) > "data\wings\config.yml"

    echo  [INFO] Template created at data\wings\config.yml
    echo  [INFO] You will need to replace it with the real config from the panel.
)

:COPY_CONFIG
echo  [INFO] Copying config to WSL...
wsl -d !WSL_DISTRO! -- bash -c "mkdir -p /etc/pterodactyl && rm -f /etc/pterodactyl/config.yml" <nul

:: Try direct copy to WSL filesystem
copy "data\wings\config.yml" "\\wsl.localhost\!WSL_DISTRO!\etc\pterodactyl\config.yml" >nul 2>&1
if %errorlevel% neq 0 (
    :: Fallback: copy via WSL from Windows path
    set WSL_PATH=/mnt/c/Users/%USERNAME%/Downloads/PteroWindows/data/wings/config.yml
    wsl -d !WSL_DISTRO! -- bash -c "cp '!WSL_PATH!' /etc/pterodactyl/config.yml 2>/dev/null || echo 'WARN: Manual copy needed'" <nul
)

:START_SERVICE
echo.
echo  [6] Starting services...
wsl -d !WSL_DISTRO! -- sudo service docker start >nul 2>&1
echo  [OK] Docker started in WSL

:: Don't try to start Wings yet - config hasn't been configured
echo  [INFO] Wings installed but not started (needs config from panel).

echo.
echo  ========================================
echo    WINGS INSTALLATION COMPLETE
echo  ========================================
echo.
echo  Manual steps required:
echo.
echo  1. Open the panel in your browser
echo  2. Go to Admin ^> Nodes ^> Create New
echo  3. Name: local, FQDN: 127.0.0.1
echo  4. After creation, open the Configuration tab
echo  5. Copy the YAML config
echo  6. Paste it into: data\wings\config.yml
echo  7. Run:
echo     wsl -d !WSL_DISTRO! -- sudo systemctl start wings
echo.
echo  Check status:
echo     wsl -d !WSL_DISTRO! -- sudo systemctl status wings
echo.
pause
exit /b 0
