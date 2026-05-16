@echo off
setlocal enabledelayedexpansion

title PteroWindows - Pterodactyl Panel Installer
color 0B

echo.
echo   ____  _        _____                     _                _   ___
echo  ^|  _ \^| ^|      ^| ____^|_ ____   _____  ___^| ^|_   ___  __ _^| ^| ^|__ \
echo  ^| ^|_) ^| ^|      ^|  _^| ^| '_ \ \ / / _ \/ __^| __^| / __^|/ _` ^| ^|   / /
echo  ^|  __/^| ^|___   ^| ^|___^| ^| ^| \ V /  __/\__ \ ^|_  \__ \ (_^| ^| ^|  ^|_^|
echo  ^|_^|   ^|_____^|  ^|_____^|_^| ^|_|\_/ \___^|^|___/\__^| ^|___/\__,_^|_^|  (_^)
echo.
echo  Pterodactyl Panel Installer for Windows
echo  Panel v1.12.2 ^| Wings v1.12.1 ^| May 15, 2026
echo.

:: --- Admin check ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo  [WARN] Not running as Administrator. Some operations may fail.
    set /p CONTINUE="  Continue anyway? (y/N): "
    if /i "!CONTINUE!" neq "y" exit /b 1
)
echo.

:: --- Step 1: Prerequisites ---
echo [1/7] Checking prerequisites...
echo.

where docker >nul 2>&1
if %errorlevel% neq 0 (
    echo  [FAIL] Docker is not installed.
    echo  Download Docker Desktop from: https://docs.docker.com/desktop/install/windows-install/
    pause
    exit /b 1
)
echo  [OK] Docker: installed

docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo  [FAIL] Docker Desktop is not running. Please start it.
    pause
    exit /b 1
)
echo  [OK] Docker daemon: running

where git >nul 2>&1
if %errorlevel% neq 0 (
    echo  [FAIL] Git is not installed.
    echo  Download from: https://git-scm.com/download/win
    pause
    exit /b 1
)
echo  [OK] Git: installed

where wsl >nul 2>&1
if %errorlevel% equ 0 (
    echo  [OK] WSL: available
) else (
    echo  [WARN] WSL not detected (only needed for Wings, not the panel)
)

echo.

:: --- Step 2: Environment ---
echo [2/7] Setting up environment...

if not exist ".env" (
    if exist ".env.example" (
        copy ".env.example" ".env" >nul
        echo  [INFO] Created .env from .env.example
        echo  [INFO] Open .env in a text editor and set your values.
        echo  [INFO] At minimum: DB_PASSWORD, DB_ROOT_PASSWORD, APP_URL
        echo.
        set /p DUMMY="  Press Enter after you've configured .env..."
    ) else (
        echo  [FAIL] .env.example not found!
        pause
        exit /b 1
    )
) else (
    echo  [OK] .env file exists
)

:: Create data directories
if not exist "data\database" mkdir "data\database"
if not exist "data\panel\var" mkdir "data\panel\var"
if not exist "data\panel\logs" mkdir "data\panel\logs"
if not exist "data\panel\nginx" mkdir "data\panel\nginx"
if not exist "data\panel\certs" mkdir "data\panel\certs"
if not exist "eggs" mkdir "eggs"
if not exist "scripts" mkdir "scripts"
echo  [OK] Directories created

echo.

:: --- Step 3: Docker Compose ---
echo [3/7] Starting Docker services...

:: Detect available compose command
docker compose version >nul 2>&1
if %errorlevel% equ 0 (
    set COMPOSE_CMD=docker compose
) else (
    docker-compose --version >nul 2>&1
    if %errorlevel% equ 0 (
        set COMPOSE_CMD=docker-compose
    ) else (
        echo  [FAIL] Docker Compose not available.
        pause
        exit /b 1
    )
)

echo  [INFO] Pulling Docker images (this may take a while)...
call %COMPOSE_CMD% pull
if %errorlevel% neq 0 (
    echo  [FAIL] Failed to pull Docker images.
    pause
    exit /b 1
)

echo  [INFO] Starting containers...
call %COMPOSE_CMD% up -d
if %errorlevel% neq 0 (
    echo  [FAIL] Failed to start containers.
    pause
    exit /b 1
)
echo  [OK] All containers started

:: Wait for panel
echo  [INFO] Waiting for panel to become ready...
set WAIT_COUNT=0
:WAIT_PANEL
timeout /t 3 /nobreak >nul
curl -s http://localhost/api/health >nul 2>&1
if %errorlevel% neq 0 (
    set /a WAIT_COUNT+=1
    if !WAIT_COUNT! lss 20 goto WAIT_PANEL
    echo  [WARN] Panel may still be starting. Check: %COMPOSE_CMD% logs panel
) else (
    echo  [OK] Panel is responding
)

echo.

:: --- Step 4: Initialize Panel ---
echo [4/7] Initializing panel...

echo  [INFO] Generating application key...
call %COMPOSE_CMD% exec -T panel php artisan key:generate --force
echo  [OK] Application key generated

echo  [INFO] Running database migrations...
call %COMPOSE_CMD% exec -T panel php artisan migrate --seed --force
if %errorlevel% neq 0 (
    echo  [FAIL] Database migration failed.
    pause
    exit /b 1
)
echo  [OK] Database migrations complete

echo.

:: --- Step 5: Create Admin User ---
echo [5/7] Creating admin user...

set /p ADMIN_EMAIL="  Admin email: "
set /p ADMIN_USER="  Admin username: "
set ADMIN_PASS=
set /p ADMIN_PASS="  Admin password: "

if "!ADMIN_PASS!"=="" (
    set ADMIN_PASS=admin123!
    echo  [INFO] Using default password: admin123!
)

call %COMPOSE_CMD% exec -T panel php artisan p:user:make --email="!ADMIN_EMAIL!" --username="!ADMIN_USER!" --name="Administrator" --password="!ADMIN_PASS!" --admin=1 2>nul

echo  [OK] Admin user created
echo.
echo  ========================================
echo    Email:    !ADMIN_EMAIL!
echo    Username: !ADMIN_USER!
echo    Password: !ADMIN_PASS!
echo  ========================================
echo  SAVE THESE CREDENTIALS!
echo.

:: --- Step 6: Download Eggs ---
echo [6/7] Downloading game server eggs...

set EGGS_URL=https://raw.githubusercontent.com/pterodactyl/game-eggs/main

call :DOWNLOAD_EGG "%EGGS_URL%/minecraft/java/paper/egg-paper.json" "eggs\egg-paper.json" "Paper"
call :DOWNLOAD_EGG "%EGGS_URL%/minecraft/java/spigot/egg-spigot.json" "eggs\egg-spigot.json" "Spigot"
call :DOWNLOAD_EGG "%EGGS_URL%/minecraft/java/fabric/egg-fabric.json" "eggs\egg-fabric.json" "Fabric"

echo.

:: --- Step 7: Summary ---
echo [7/7] Installation Summary
echo ========================================
echo  Panel:    http://localhost
echo  Panel:    v1.12.2
echo  Wings:    v1.12.1
echo  Data:     %CD%\data
echo  Eggs:     %CD%\eggs
echo ========================================
echo.
echo  Next steps:
echo    1. Run .\install-wings.bat to set up Wings daemon
echo    2. Run .\update-all.bat to update everything
echo    3. Check logs: %COMPOSE_CMD% logs panel
echo.
echo  Installation complete! Open http://localhost in your browser.
echo.

pause
exit /b 0

:DOWNLOAD_EGG
set "SRC=%~1"
set "DST=%~2"
set "NAME=%~3"
if exist "%DST%" (
    echo  [OK] %NAME% egg already exists
    exit /b 0
)
echo  [DL] Downloading %NAME% egg...
curl -s -o "%DST%" "%SRC%" >nul 2>&1
if %errorlevel% equ 0 (
    echo  [OK] %NAME% saved
) else (
    echo  [WARN] Failed to download %NAME%
)
exit /b 0
