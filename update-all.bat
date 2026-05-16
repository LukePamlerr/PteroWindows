@echo off
setlocal enabledelayedexpansion

title PteroWindows - Auto Updater
color 0E

echo.
echo   _   _ ____  _   _ _____    __     ____
echo  ^| ^| ^| ^|  _ \^| ^| ^| ^|_   _^|   \ \   / / ^|
echo  ^| ^| ^| ^| ^|_) ^| ^| ^| ^| ^| ^|_____ \ \ / /^| ^|
echo  ^| ^|_^| ^|  __/^| ^|_^| ^| ^| ^|_____^| \ V / ^| ^|___
echo   \___/^|_^|    \___/  ^|_^|       \_/  ^|_____^|
echo.
echo  Auto-Updater for PteroWindows
echo.

:: Check if Docker is running
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo  [FAIL] Docker is not running. Please start Docker Desktop.
    pause
    exit /b 1
)

:: Detect compose command
docker compose version >nul 2>&1
if %errorlevel% equ 0 (
    set COMPOSE_CMD=docker compose
) else (
    docker-compose --version >nul 2>&1
    if %errorlevel% equ 0 (
        set COMPOSE_CMD=docker-compose
    ) else (
        echo  [FAIL] Docker Compose not found.
        pause
        exit /b 1
    )
)

:: --- Step 1: Update Panel ---
echo [1/3] Updating Pterodactyl Panel...

echo  [INFO] Pulling latest panel image...
call %COMPOSE_CMD% pull panel
if %errorlevel% neq 0 (
    echo  [WARN] Panel image pull failed.
) else (
    echo  [OK] Panel image pulled
)

echo  [INFO] Recreating panel container...
call %COMPOSE_CMD% up -d --force-recreate panel

echo  [INFO] Running database migrations...
call %COMPOSE_CMD% exec -T panel php artisan migrate --seed --force 2>nul

echo  [INFO] Clearing caches...
call %COMPOSE_CMD% exec -T panel php artisan view:clear 2>nul
call %COMPOSE_CMD% exec -T panel php artisan config:clear 2>nul

echo  [OK] Panel update complete

echo.

:: --- Step 2: Update Wings ---
echo [2/3] Updating Wings daemon...

where wsl >nul 2>&1
if %errorlevel% neq 0 (
    echo  [SKIP] WSL not available. Skipping Wings update.
    goto :UPDATE_EGGS
)

set WSL_DISTRO=Ubuntu-22.04
for /f "tokens=*" %%d in ('wsl --list --quiet ^| find "Ubuntu"') do set WSL_DISTRO=%%d

echo  [INFO] Downloading latest Wings binary into !WSL_DISTRO!...
wsl -d !WSL_DISTRO! -- bash -c "curl -L -o /usr/local/bin/wings.new https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64 && chmod +x /usr/local/bin/wings.new && mv /usr/local/bin/wings.new /usr/local/bin/wings"
if %errorlevel% equ 0 (
    wsl -d !WSL_DISTRO! -- sudo systemctl restart wings 2>nul
    echo  [OK] Wings updated and restarted
) else (
    echo  [WARN] Wings update failed
)

echo.

:: --- Step 3: Update Eggs ---
:UPDATE_EGGS
echo [3/3] Refreshing egg definitions...

set EGGS_URL=https://raw.githubusercontent.com/pterodactyl/game-eggs/main

if not exist "eggs" mkdir eggs

call :DOWNLOAD_EGG "%EGGS_URL%/minecraft/java/paper/egg-paper.json" "eggs\egg-paper.json" "Paper"
call :DOWNLOAD_EGG "%EGGS_URL%/minecraft/java/spigot/egg-spigot.json" "eggs\egg-spigot.json" "Spigot"
call :DOWNLOAD_EGG "%EGGS_URL%/minecraft/java/fabric/egg-fabric.json" "eggs\egg-fabric.json" "Fabric"

echo  [OK] Egg refresh complete

echo.
echo ========================================
echo  All updates complete!
echo  Panel:  http://localhost
echo  Wings:  wsl -d !WSL_DISTRO! -- sudo systemctl status wings
echo ========================================
echo.
pause
exit /b 0

:DOWNLOAD_EGG
set "SRC=%~1"
set "DST=%~2"
set "NAME=%~3"
echo  [DL] %NAME%...
curl -s -o "%DST%" "%SRC%" >nul 2>&1
if %errorlevel% equ 0 (
    echo  [OK] %NAME% updated
) else (
    echo  [WARN] Failed to download %NAME%
)
exit /b 0
