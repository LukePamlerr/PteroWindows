@echo off
setlocal enabledelayedexpansion

title PteroWindows - Egg Importer
color 0D

echo.
echo  ========================================
echo    PteroWindows Egg Importer
echo  ========================================
echo.

:: Parse --category argument
set CATEGORY=All
:ARGS
if not "%~1"=="" (
    if /i "%~1"=="--category" set CATEGORY=%~2
    shift
    goto ARGS
)

:: Set output directory
set OUTPUT_DIR=%~dp0..\eggs
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

set DOWNLOADED=0
set SKIPPED=0

:: Minecraft Java eggs
call :TRY_DOWNLOAD "Paper" "Minecraft" "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/paper/egg-paper.json"
call :TRY_DOWNLOAD "Spigot" "Minecraft" "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/spigot/egg-spigot.json"
call :TRY_DOWNLOAD "Fabric" "Minecraft" "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/fabric/egg-fabric.json"
call :TRY_DOWNLOAD "Forge" "Minecraft" "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/forge/egg-forge.json"
call :TRY_DOWNLOAD "CurseForge" "Minecraft" "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/curseforge/egg-curseforge-generic.json"
call :TRY_DOWNLOAD "BungeeCord" "Minecraft" "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/bungeecord/egg-bungeecord.json"
call :TRY_DOWNLOAD "Purpur" "Minecraft" "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/purpur/egg-purpur.json"
call :TRY_DOWNLOAD "Folia" "Minecraft" "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/folia/egg-folia.json"
call :TRY_DOWNLOAD "NeoForge" "Minecraft" "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/neoforge/egg-neoforge.json"
call :TRY_DOWNLOAD "Magma" "Minecraft" "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/magma/egg-magma.json"

:: Application eggs
call :TRY_DOWNLOAD "Gitea" "Software" "https://raw.githubusercontent.com/pterodactyl/application-eggs/main/gitea/egg-gitea.json"
call :TRY_DOWNLOAD "UptimeKuma" "Software" "https://raw.githubusercontent.com/pterodactyl/application-eggs/main/uptime-kuma/egg-uptime-kuma.json"
call :TRY_DOWNLOAD "Grafana" "Software" "https://raw.githubusercontent.com/pterodactyl/application-eggs/main/grafana/egg-grafana.json"
call :TRY_DOWNLOAD "CodeServer" "Software" "https://raw.githubusercontent.com/pterodactyl/application-eggs/main/code-server/egg-code-server.json"
call :TRY_DOWNLOAD "Lavalink" "Software" "https://raw.githubusercontent.com/pterodactyl/application-eggs/main/lavalink/egg-lavalink.json"
call :TRY_DOWNLOAD "Meilisearch" "Software" "https://raw.githubusercontent.com/pterodactyl/application-eggs/main/meilisearch/egg-meilisearch.json"
call :TRY_DOWNLOAD "Minio" "Storage" "https://raw.githubusercontent.com/pterodactyl/application-eggs/main/minio/egg-minio.json"
call :TRY_DOWNLOAD "Elasticsearch" "Software" "https://raw.githubusercontent.com/pterodactyl/application-eggs/main/elasticsearch/egg-elasticsearch.json"

echo.
echo  ========================================
echo    Downloaded: %DOWNLOADED%  |  Skipped: %SKIPPED%
echo    Eggs saved to: %OUTPUT_DIR%
echo  ========================================
echo.
echo  To import into the panel via API:
echo    Get an Application API key from Admin ^> Application API
echo    Then use the panel's egg import feature directly.
echo.
pause
exit /b 0

:TRY_DOWNLOAD
set "NAME=%~1"
set "CAT=%~2"
set "URL=%~3"

:: Category filter
if /i not "%CATEGORY%"=="All" (
    if /i not "%CATEGORY%"=="%CAT%" exit /b 0
)

set "FILE=%OUTPUT_DIR%\%NAME%.json"

if exist "!FILE!" (
    set /a SKIPPED+=1
    exit /b 0
)

echo  [DL] !NAME!...
curl -s -o "!FILE!" "!URL!" >nul 2>&1
if !errorlevel! equ 0 (
    echo  [OK] !NAME!
    set /a DOWNLOADED+=1
) else (
    echo  [ERR] !NAME! failed
)
exit /b 0
