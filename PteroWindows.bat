@echo off
setlocal enabledelayedexpansion
title PteroWindows - Main Menu
color 0B

:MENU
cls
echo.
echo  ##############################################################
echo  #                                                            #
echo  #     ____  _        _____                     _             #
echo  #    |  _ \| |      | ____|_ ____   _____  ___| |_           #
echo  #    | |_) | |      |  _| | '_ \ \ / / _ \/ __| __|          #
echo  #    |  __/| |___   | |___| | | \ V /  __/\__ \ |_           #
echo  #    |_|   |_____|  |_____|_| |_|\_/ \___||___/\__|          #
echo  #                                                            #
echo  #    PteroWindows v1.0.0 - Pterodactyl Panel for Windows     #
echo  #    Panel v1.12.2 | Wings v1.12.1 | May 15, 2026            #
echo  #                                                            #
echo  ##############################################################
echo.
echo  1. Install Panel
echo  2. Install Wings (Daemon via WSL2)
echo  3. Update Everything
echo  4. Configure Custom Domain
echo  5. Download/Import Eggs
echo  6. View Panel Status
echo  7. Restart All Services
echo  8. Stop All Services
echo  9. View Logs
echo  0. Exit
echo.
set /p CHOICE="  Select an option [0-9]: "

if "!CHOICE!"=="1" goto :INSTALL_PANEL
if "!CHOICE!"=="2" goto :INSTALL_WINGS
if "!CHOICE!"=="3" goto :UPDATE_ALL
if "!CHOICE!"=="4" goto :CONFIGURE_DOMAIN
if "!CHOICE!"=="5" goto :IMPORT_EGGS
if "!CHOICE!"=="6" goto :VIEW_STATUS
if "!CHOICE!"=="7" goto :RESTART_ALL
if "!CHOICE!"=="8" goto :STOP_ALL
if "!CHOICE!"=="9" goto :VIEW_LOGS
if "!CHOICE!"=="0" goto :EOF

echo  Invalid option. Press any key to try again...
pause >nul
goto MENU

:INSTALL_PANEL
cls
echo. && echo  Launching Panel Installer... && echo.
call install-panel.bat
echo. && echo  Press any key to return to menu... && pause >nul
goto MENU

:INSTALL_WINGS
cls
echo. && echo  Launching Wings Installer... && echo.
call install-wings.bat
echo. && echo  Press any key to return to menu... && pause >nul
goto MENU

:UPDATE_ALL
cls
echo. && echo  Launching Updater... && echo.
call update-all.bat
echo. && echo  Press any key to return to menu... && pause >nul
goto MENU

:CONFIGURE_DOMAIN
cls
echo.
echo  ##############################################################
echo  #          Configure Custom Domain / SSL                     #
echo  ##############################################################
echo.
echo  Current APP_URL from .env:
if exist ".env" (
    for /f "tokens=1,* delims==" %%a in ('findstr /b "APP_URL" .env') do echo    %%a=%%b
) else (
    echo    (no .env file found)
)
for /f "tokens=1,* delims==" %%a in ('findstr /b "LE_EMAIL" .env 2^>nul') do set CURRENT_LE=%%b
echo  Current LE_EMAIL: %CURRENT_LE%
echo.
echo  Enter your domain (e.g. panel.yourdomain.com or localhost):
set /p NEW_DOMAIN="  Domain: "
if "!NEW_DOMAIN!"=="" (
    echo  [WARN] No domain entered. Skipping.
    pause
    goto MENU
)
set /p NEW_LE_EMAIL="  Let's Encrypt email (leave blank to skip SSL): "

:: Update .env
if exist ".env" (
    if "!NEW_DOMAIN:~0,8!"=="https://" (
        set FULL_URL=!NEW_DOMAIN!
    ) else (
        set FULL_URL=https://!NEW_DOMAIN!
    )
    :: Replace APP_URL in .env
    findstr /v /b "APP_URL" .env > .env.tmp
    echo APP_URL=!FULL_URL!>> .env.tmp
    move /y .env.tmp .env >nul

    if not "!NEW_LE_EMAIL!"=="" (
        findstr /v /b "LE_EMAIL" .env > .env.tmp
        echo LE_EMAIL=!NEW_LE_EMAIL!>> .env.tmp
        move /y .env.tmp .env >nul
    )
    echo  [OK] .env updated
) else (
    echo  [FAIL] .env not found. Run install-panel.bat first.
    pause
    goto MENU
)

:: Restart panel to pick up new domain
echo  [INFO] Restarting panel with new domain...
where docker >nul 2>&1
if %errorlevel% equ 0 (
    docker compose up -d --force-recreate panel >nul 2>&1 || docker-compose up -d --force-recreate panel >nul 2>&1
    echo  [OK] Panel restarted with domain: !FULL_URL!
) else (
    echo  [WARN] Docker not running. Domain saved in .env but panel not restarted.
)
echo.
echo  ========================================
echo    Domain: !FULL_URL!
echo    LE_EMAIL: !NEW_LE_EMAIL!
echo  ========================================
echo.
echo  Ensure your DNS points to this Windows machine.
echo  Allow ports 80 and 443 through Windows Firewall.
echo.
pause
goto MENU

:IMPORT_EGGS
cls
echo. && echo  Launching Egg Importer... && echo.
call scripts\import-eggs.bat
echo. && echo  Press any key to return to menu... && pause >nul
goto MENU

:VIEW_STATUS
cls
echo.
echo  ##############################################################
echo  #                 Panel Status                              #
echo  ##############################################################
echo.
where docker >nul 2>&1
if %errorlevel% neq 0 (
    echo  [FAIL] Docker not installed.
    pause
    goto MENU
)

docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo  [FAIL] Docker not running.
    pause
    goto MENU
)

echo  Docker: running
echo.

:: Check containers
docker compose ps 2>nul || docker-compose ps 2>nul
echo.

:: Check panel health
echo  Panel health check:
curl -s http://localhost/api/health >nul 2>&1
if %errorlevel% equ 0 (
    echo    [OK] Panel is responding
) else (
    echo    [WARN] Panel not responding (may still be starting or on a different port)
)

:: Check .env config
echo.
echo  Current configuration:
if exist ".env" (
    for /f "tokens=1,* delims==" %%a in ('findstr /b "APP_URL APP_TIMEZONE APP_ENV HTTP_PORT HTTPS_PORT" .env') do echo    %%a=%%b
) else (
    echo    No .env file found
)

:: Check disk usage
echo.
echo  Data directory size:
if exist "data" (
    powershell -command "$p=Get-ChildItem 'data' -Recurse -ErrorAction SilentlyContinue; $s=($p | Measure-Object Length -Sum).Sum; if($s -gt 1GB){'{0:N2} GB' -f ($s/1GB)}elseif($s -gt 1MB){'{0:N2} MB' -f ($s/1MB)}else{'< 1 MB'}" 2>nul
) else (
    echo    No data directory
)

echo.
pause
goto MENU

:RESTART_ALL
cls
echo.
echo  Restarting all services...
echo.

where docker >nul 2>&1
if %errorlevel% neq 0 (
    echo  [FAIL] Docker not installed.
    pause
    goto MENU
)

docker compose restart >nul 2>&1 || docker-compose restart >nul 2>&1
if %errorlevel% equ 0 (
    echo  [OK] All services restarted
) else (
    echo  [FAIL] Failed to restart services
)

:: Also try to restart Wings in WSL
where wsl >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%d in ('wsl --list --quiet ^| find "Ubuntu"') do (
        wsl -d %%d -- sudo systemctl restart wings 2>nul
        echo  [OK] Wings restarted in %%d
    )
)
echo.
pause
goto MENU

:STOP_ALL
cls
echo.
echo  Stopping all services...
echo.

where docker >nul 2>&1
if %errorlevel% neq 0 (
    echo  [FAIL] Docker not installed.
    pause
    goto MENU
)

docker compose down >nul 2>&1 || docker-compose down >nul 2>&1
if %errorlevel% equ 0 (
    echo  [OK] All services stopped
) else (
    echo  [FAIL] Failed to stop services
)
echo.
pause
goto MENU

:VIEW_LOGS
cls
echo.
echo  ##############################################################
echo  #                   Panel Logs                              #
echo  ##############################################################
echo.
echo  Select log to view:
echo  1. Panel log
echo  2. Database log
echo  3. Panel access log (nginx)
echo  4. Back to menu
echo.
set /p LOG_CHOICE="  Select [1-4]: "

where docker >nul 2>&1
if %errorlevel% neq 0 (
    echo  [FAIL] Docker not installed.
    pause
    goto MENU
)

if "!LOG_CHOICE!"=="1" (
    docker compose logs panel 2>nul || docker-compose logs panel 2>nul
    pause
    goto VIEW_LOGS
)
if "!LOG_CHOICE!"=="2" (
    docker compose logs database 2>nul || docker-compose logs database 2>nul
    pause
    goto VIEW_LOGS
)
if "!LOG_CHOICE!"=="3" (
    if exist "data\panel\logs" (
        echo  Contents of data\panel\logs:
        dir /b "data\panel\logs\*.log" 2>nul
        echo.
        set /p LOG_FILE="  Enter log filename: "
        if exist "data\panel\logs\!LOG_FILE!" (
            type "data\panel\logs\!LOG_FILE!"
        ) else (
            echo  File not found.
        )
    ) else (
        docker compose exec -T panel ls -la /app/storage/logs/ 2>nul || docker-compose exec -T panel ls -la /app/storage/logs/ 2>nul
    )
    pause
    goto VIEW_LOGS
)
goto MENU
