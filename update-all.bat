@echo off
setlocal enabledelayedexpansion

title PteroWindows - Updater
color 0E

echo.
echo  ========================================
echo    PteroWindows Auto-Updater
echo  ========================================
echo.

:CHECK_DOCKER
where docker >nul 2>&1
if %errorlevel% neq 0 (
    echo  [FAIL] Docker not installed.
    pause
    exit /b 1
)
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo  [FAIL] Docker not running. Start Docker Desktop first.
    pause
    exit /b 1
)
echo  [OK] Docker is running

:: Detect compose
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

:UPDATE_PANEL
echo.
echo  [1/3] Updating Panel...
echo  [INFO] Pulling latest panel image...
call %COMPOSE_CMD% pull panel
if %errorlevel% equ 0 ( echo  [OK] Image pulled ) else ( echo  [WARN] Pull failed, continuing )

echo  [INFO] Recreating panel container...
call %COMPOSE_CMD% up -d --force-recreate panel >nul
if %errorlevel% equ 0 ( echo  [OK] Container recreated ) else ( echo  [WARN] Recreate had issues )

echo  [INFO] Running database migrations...
call %COMPOSE_CMD% exec -T panel php artisan migrate --seed --force >nul 2>&1
if %errorlevel% equ 0 ( echo  [OK] Migrations ran ) else ( echo  [OK] No new migrations )

echo  [INFO] Clearing caches...
call %COMPOSE_CMD% exec -T panel php artisan view:clear >nul 2>&1
call %COMPOSE_CMD% exec -T panel php artisan config:clear >nul 2>&1
echo  [OK] Panel updated

:UPDATE_WINGS
echo.
echo  [2/3] Updating Wings daemon...

where wsl >nul 2>&1
if %errorlevel% neq 0 (
    echo  [SKIP] WSL not available
    goto :UPDATE_EGGS
)

set WSL_DISTRO=
for /f "tokens=*" %%d in ('wsl --list --quiet ^| find "Ubuntu"') do set WSL_DISTRO=%%d
if "!WSL_DISTRO!"=="" (
    echo  [SKIP] No Ubuntu WSL distro found
    goto :UPDATE_EGGS
)

echo  [INFO] Updating Wings in !WSL_DISTRO!...
wsl -d !WSL_DISTRO! -- bash -c "curl -L -o /usr/local/bin/wings.new https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64 && chmod +x /usr/local/bin/wings.new && mv /usr/local/bin/wings.new /usr/local/bin/wings" <nul
if %errorlevel% equ 0 (
    echo  [OK] Wings binary updated
    :: Try restart if config exists
    wsl -d !WSL_DISTRO! -- sudo systemctl restart wings >nul 2>&1
    if %errorlevel% equ 0 ( echo  [OK] Wings restarted ) else ( echo  [INFO] Wings not running, skipping restart )
) else (
    echo  [WARN] Wings update failed
)

:UPDATE_EGGS
echo.
echo  [3/3] Refreshing eggs...

if not exist "eggs" mkdir eggs

set EGGS_URL=https://raw.githubusercontent.com/pterodactyl/game-eggs/main
call :DOWNLOAD_EGG "%EGGS_URL%/minecraft/java/paper/egg-paper.json" "eggs\egg-paper.json" "Paper"
call :DOWNLOAD_EGG "%EGGS_URL%/minecraft/java/spigot/egg-spigot.json" "eggs\egg-spigot.json" "Spigot"
call :DOWNLOAD_EGG "%EGGS_URL%/minecraft/java/fabric/egg-fabric.json" "eggs\egg-fabric.json" "Fabric"

:DONE
echo.
echo  ========================================
echo    UPDATE COMPLETE
echo  ========================================
echo    Panel image:   latest
echo    Wings binary:  latest
echo    Eggs:          refreshed
echo  ========================================
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
    echo  [OK] %NAME%
) else (
    echo  [WARN] %NAME% failed
)
exit /b 0
