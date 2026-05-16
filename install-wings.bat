@echo off
setlocal enabledelayedexpansion

title PteroWindows - Wings Daemon Installer
color 0C

echo.
echo   __        ___ _ __   __ _ _ __ ___   ___
echo   \ \      / _ \ '_ \ / _` ^| '_ ` _ \ / _ \
echo    \ \ /\ / / __/ ^| ^| ^| (_^| ^| ^| ^| ^| ^| ^|  __/
echo     \ V  V / \___^|_^| ^|_|\__,_^|_^| ^|_^| ^|_|\___^|
echo.
echo  Wings Daemon Installer for Windows (via WSL2)
echo.

:: --- Admin check ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo  [WARN] Not running as Administrator. WSL operations may fail.
    set /p CONTINUE="  Continue anyway? (y/N): "
    if /i "!CONTINUE!" neq "y" exit /b 1
)
echo.

:: --- Step 1: Prerequisites ---
echo [1/6] Checking prerequisites...

where wsl >nul 2>&1
if %errorlevel% neq 0 (
    echo  [FAIL] WSL is not installed.
    echo  Run the following as Administrator, then restart:
    echo    wsl --install
    pause
    exit /b 1
)
echo  [OK] WSL is available

:: Check WSL2 default
wsl --status | find "Default Version: 2" >nul 2>&1
if %errorlevel% neq 0 (
    echo  [WARN] WSL2 is not the default. Setting it...
    wsl --set-default-version 2 >nul 2>&1
)

:: Check for Ubuntu distro
set WSL_DISTRO=Ubuntu-22.04
wsl --list --quiet | find "Ubuntu" >nul 2>&1
if %errorlevel% neq 0 (
    echo  [INFO] Ubuntu WSL distro not found. Installing...
    wsl --install -d Ubuntu-22.04
    if %errorlevel% neq 0 (
        echo  [FAIL] Failed to install Ubuntu WSL.
        pause
        exit /b 1
    )
    echo  [OK] Ubuntu installed
) else (
    for /f "tokens=*" %%d in ('wsl --list --quiet ^| find "Ubuntu"') do set WSL_DISTRO=%%d
    echo  [OK] WSL distro: !WSL_DISTRO!
)
echo.

:: --- Step 2: Docker in WSL ---
echo [2/6] Installing Docker Engine in WSL...

wsl -d !WSL_DISTRO! -- which docker >nul 2>&1
if %errorlevel% equ 0 (
    echo  [OK] Docker is already installed in WSL
) else (
    echo  [INFO] Installing Docker Engine in WSL (this takes a moment)...
    wsl -d !WSL_DISTRO! -- bash -c "curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh && sudo usermod -aG docker \$USER && rm get-docker.sh"
    if %errorlevel% neq 0 (
        echo  [FAIL] Failed to install Docker Engine in WSL.
        pause
        exit /b 1
    )
    echo  [OK] Docker Engine installed
)
echo.

:: --- Step 3: Download Wings ---
echo [3/6] Downloading Wings binary...

wsl -d !WSL_DISTRO! -- which wings >nul 2>&1
if %errorlevel% equ 0 (
    echo  [OK] Wings already installed
) else (
    echo  [INFO] Downloading latest Wings release...
    wsl -d !WSL_DISTRO! -- bash -c "mkdir -p /etc/pterodactyl && curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64 && chmod +x /usr/local/bin/wings"
    if %errorlevel% neq 0 (
        echo  [FAIL] Failed to download Wings.
        pause
        exit /b 1
    )
    echo  [OK] Wings binary installed
)
echo.

:: --- Step 4: Configure Service ---
echo [4/6] Configuring Wings service...

wsl -d !WSL_DISTRO! -- bash -c "cat > /etc/systemd/system/wings.service << 'EOF'
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
systemctl enable wings"
echo  [OK] Wings service configured

echo.

:: --- Step 5: Generate Config ---
echo [5/6] Generating Wings configuration...

if not exist "data\wings" mkdir "data\wings"
if exist "data\wings\config.yml" (
    echo  [OK] Config already exists at data\wings\config.yml
) else (
    echo  [INFO] Create a Node in the panel (Admin ^> Nodes ^> Create New)
    echo  [INFO] Use 127.0.0.1 as FQDN for local setup
    echo  [INFO] Then copy the config from the Configuration tab
    echo  [INFO] and save it to data\wings\config.yml
    echo.

    :: Write a placeholder config
    (
        echo # Pterodactyl Wings Configuration
        echo # WARNING: Replace this with the config from
        echo # Admin ^> Nodes ^> [Your Node] ^> Configuration
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
    echo  [WARN] Template created at data\wings\config.yml
    echo  [WARN] You MUST replace with the real config from the panel!
)
echo.

:: --- Step 6: Start ---
echo [6/6] Starting Wings daemon...

echo  [INFO] Copying config to WSL...
wsl -d !WSL_DISTRO! -- bash -c "mkdir -p /etc/pterodactyl"
wsl -d !WSL_DISTRO! -- cp /mnt/c/Users/%USERNAME%/Downloads/PteroWindows/data/wings/config.yml /etc/pterodactyl/config.yml 2>nul
:: Alternative copy if the above fails
copy "data\wings\config.yml" "\\wsl.localhost\!WSL_DISTRO!\etc\pterodactyl\config.yml" >nul 2>&1

echo  [INFO] Starting Docker and Wings...
wsl -d !WSL_DISTRO! -- sudo service docker start >nul 2>&1
wsl -d !WSL_DISTRO! -- sudo systemctl start wings 2>nul

echo.
echo ========================================
echo  Wings installation complete!
echo ========================================
echo.
echo  Please complete these manual steps:
echo.
echo  1. Open http://localhost in your browser
echo  2. Go to Admin ^> Nodes ^> Create New
echo  3. Name: local, FQDN: 127.0.0.1
echo  4. After creation, open the Configuration tab
echo  5. Copy the full config to data\wings\config.yml
echo  6. Restart Wings:
echo     wsl -d !WSL_DISTRO! -- sudo systemctl restart wings
echo.
echo  Check Wings status:
echo     wsl -d !WSL_DISTRO! -- sudo systemctl status wings
echo.
pause
exit /b 0
