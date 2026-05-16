@echo off
setlocal enabledelayedexpansion

title PteroWindows - Panel Installer
color 0B

echo.
echo  ========================================
echo    Pterodactyl Panel Installer
echo    v1.12.2 | May 15, 2026
echo  ========================================
echo.

:ADMIN_CHECK
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo  [WARN] Not running as Administrator. Some operations may fail.
    set /p CONTINUE="  Continue? (y/N): "
    if /i "!CONTINUE!" neq "y" exit /b 1
)

:CHECK_DOCKER
echo  [1] Checking Docker...
where docker >nul 2>&1
if %errorlevel% neq 0 (
    echo  [FAIL] Docker not installed.
    echo  Download: https://docs.docker.com/desktop/install/windows-install/
    pause
    exit /b 1
)
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo  [FAIL] Docker Desktop not running. Please start it.
    pause
    exit /b 1
)
echo  [OK] Docker is installed and running

:: Detect compose command
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

:CHECK_GIT
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo  [WARN] Git not installed. Download: https://git-scm.com/download/win
) else (
    echo  [OK] Git is available
)

:SETUP_ENV
echo.
echo  [2] Setting up environment...

if not exist ".env" (
    if exist ".env.example" (
        copy ".env.example" ".env" >nul
        echo  [INFO] Created .env from .env.example
        echo.
        echo  Would you like to configure your domain now?
        set /p SET_DOMAIN="  Configure domain? (y/N): "
        if /i "!SET_DOMAIN!"=="y" (
            set /p NEW_URL="  Panel URL (e.g. http://localhost or https://panel.example.com): "
            if not "!NEW_URL!"=="" (
                findstr /v /b "APP_URL" .env > .env.tmp
                echo APP_URL=!NEW_URL!>> .env.tmp
                move /y .env.tmp .env >nul
                echo  [OK] APP_URL set to !NEW_URL!
            )
            set /p LE_MAIL="  Let's Encrypt email (for SSL, press Enter to skip): "
            if not "!LE_MAIL!"=="" (
                findstr /v /b "LE_EMAIL" .env > .env.tmp
                echo LE_EMAIL=!LE_MAIL!>> .env.tmp
                move /y .env.tmp .env >nul
                echo  [OK] LE_EMAIL set
            )
        )
        echo.
        echo  [INFO] Generate database passwords? (y/N)
        set /p GEN_PASS="  Generate: "
        if /i "!GEN_PASS!"=="y" (
            :: Generate random passwords using PowerShell
            for /f %%p in ('powershell -command "[System.Convert]::ToBase64String((1..24|%%{Get-Random -Max 256}))" 2^>nul') do set DB_PASS=%%p
            for /f %%p in ('powershell -command "[System.Convert]::ToBase64String((1..24|%%{Get-Random -Max 256}))" 2^>nul') do set ROOT_PASS=%%p
            if not "!DB_PASS!"=="" (
                findstr /v /b "DB_PASSWORD" .env > .env.tmp
                echo DB_PASSWORD=!DB_PASS!>> .env.tmp
                move /y .env.tmp .env >nul
            )
            if not "!ROOT_PASS!"=="" (
                findstr /v /b "DB_ROOT_PASSWORD" .env > .env.tmp
                echo DB_ROOT_PASSWORD=!ROOT_PASS!>> .env.tmp
                move /y .env.tmp .env >nul
            )
            echo  [OK] Database passwords generated and saved to .env
        )
    ) else (
        echo  [FAIL] .env.example not found.
        pause
        exit /b 1
    )
) else (
    echo  [OK] .env found
)

:CREATE_DIRS
if not exist "data\database" mkdir "data\database"
if not exist "data\panel\var" mkdir "data\panel\var"
if not exist "data\panel\logs" mkdir "data\panel\logs"
if not exist "data\panel\nginx" mkdir "data\panel\nginx"
if not exist "data\panel\certs" mkdir "data\panel\certs"
if not exist "eggs" mkdir "eggs"
if not exist "scripts" mkdir "scripts"
echo  [OK] Data directories created

:PULL_IMAGES
echo.
echo  [3] Pulling Docker images (this may take a while)...
call %COMPOSE_CMD% pull
if %errorlevel% neq 0 (
    echo  [WARN] Image pull failed. Continuing anyway...
) else (
    echo  [OK] Images pulled
)

:START_CONTAINERS
echo  [4] Starting containers...
call %COMPOSE_CMD% up -d
if %errorlevel% neq 0 (
    echo  [FAIL] Failed to start containers.
    call %COMPOSE_CMD% logs panel
    pause
    exit /b 1
)
echo  [OK] Containers started

:WAIT_FOR_PANEL
echo  [5] Waiting for panel to become ready...
set WAIT_COUNT=0
:WAIT_LOOP
timeout /t 3 /nobreak >nul
curl -s http://localhost/api/health >nul 2>&1
if %errorlevel% neq 0 (
    set /a WAIT_COUNT+=1
    if !WAIT_COUNT! lss 30 goto WAIT_LOOP
    echo  [WARN] Panel not responding yet. Continuing anyway...
) else (
    echo  [OK] Panel is responding
)

:INIT_PANEL
echo  [6] Initializing panel...

echo  [INFO] Generating application key...
call %COMPOSE_CMD% exec -T panel php artisan key:generate --force

echo  [INFO] Running database migrations...
call %COMPOSE_CMD% exec -T panel php artisan migrate --seed --force
if %errorlevel% neq 0 (
    echo  [FAIL] Database migration failed. Check: %COMPOSE_CMD% logs panel
    pause
    exit /b 1
)
echo  [OK] Database ready

:CREATE_ADMIN
echo.
echo  [7] Creating admin user...
echo.

:: Read APP_URL from .env for display
for /f "tokens=1,* delims==" %%a in ('findstr /b "APP_URL" .env 2^>nul') do set PANEL_URL=%%b
if "!PANEL_URL!"=="" set PANEL_URL=http://localhost

set /p ADMIN_EMAIL="  Email:      "
set /p ADMIN_USER="  Username:   "
set ADMIN_PASS=
set /p ADMIN_PASS="  Password:   "
if "!ADMIN_PASS!"=="" (
    for /f %%p in ('powershell -command "-join((33..126|%%{[char]$_|Get-Random})[0..15])" 2^>nul') do set ADMIN_PASS=%%p
    if "!ADMIN_PASS!"=="" set ADMIN_PASS=PteroAdmin2026!
    echo  [INFO] Auto-generated password: !ADMIN_PASS!
)

call %COMPOSE_CMD% exec -T panel php artisan p:user:make --email="!ADMIN_EMAIL!" --username="!ADMIN_USER!" --name="Administrator" --password="!ADMIN_PASS!" --admin=1 2>nul

echo.
echo  ========================================
echo    ADMIN CREDENTIALS - SAVE THESE
echo  ========================================
echo    URL:      !PANEL_URL!
echo    Email:    !ADMIN_EMAIL!
echo    Username: !ADMIN_USER!
echo    Password: !ADMIN_PASS!
echo  ========================================

:DOWNLOAD_EGGS
echo.
echo  [8] Downloading game server eggs...
set EGGS_URL=https://raw.githubusercontent.com/pterodactyl/game-eggs/main
call :DOWNLOAD_EGG "%EGGS_URL%/minecraft/java/paper/egg-paper.json" "eggs\egg-paper.json" "Paper"
call :DOWNLOAD_EGG "%EGGS_URL%/minecraft/java/spigot/egg-spigot.json" "eggs\egg-spigot.json" "Spigot"
call :DOWNLOAD_EGG "%EGGS_URL%/minecraft/java/fabric/egg-fabric.json" "eggs\egg-fabric.json" "Fabric"

:SUMMARY
echo.
echo  ========================================
echo    INSTALLATION COMPLETE
echo  ========================================
echo    Panel:  !PANEL_URL!
echo    Panel:  v1.12.2
echo    Wings:  v1.12.1
echo    Data:   %CD%\data
echo    Eggs:   %CD%\eggs
echo  ========================================
echo.
echo  Next steps from the main menu:
echo    Option 2: Install Wings daemon
echo    Option 4: Configure custom domain
echo    Option 5: Import more eggs
echo.
echo  Open !PANEL_URL! in your browser.
echo.
pause
exit /b 0

:DOWNLOAD_EGG
set "SRC=%~1"
set "DST=%~2"
set "NAME=%~3"
if exist "%DST%" ( exit /b 0 )
curl -s -o "%DST%" "%SRC%" >nul 2>&1
if %errorlevel% equ 0 (
    echo  [OK] %NAME%
) else (
    echo  [WARN] %NAME% failed
)
exit /b 0
