@echo off
setlocal enabledelayedexpansion

title PteroWindows - Egg Importer
color 0D

echo.
echo  PteroWindows Egg Importer
echo  ========================
echo.

:: Parse arguments
set CATEGORY=All
set PANEL_URL=
set API_KEY=

:PARSE_ARGS
if "%~1"=="" goto :ARG_DONE
if /i "%~1"=="--category" set CATEGORY=%~2& shift & shift & goto PARSE_ARGS
if /i "%~1"=="--panel-url" set PANEL_URL=%~2& shift & shift & goto PARSE_ARGS
if /i "%~1"=="--api-key" set API_KEY=%~2& shift & shift & goto PARSE_ARGS
if /i "%~1"=="/?" goto :SHOW_HELP
shift
goto PARSE_ARGS
:ARG_DONE

:: Define egg sources
set EGG_SOURCES[0].Name=Paper
set EGG_SOURCES[0].Category=Minecraft
set EGG_SOURCES[0].Url=https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/paper/egg-paper.json

set EGG_SOURCES[1].Name=Spigot
set EGG_SOURCES[1].Category=Minecraft
set EGG_SOURCES[1].Url=https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/spigot/egg-spigot.json

set EGG_SOURCES[2].Name=Fabric
set EGG_SOURCES[2].Category=Minecraft
set EGG_SOURCES[2].Url=https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/fabric/egg-fabric.json

set EGG_SOURCES[3].Name=Forge
set EGG_SOURCES[3].Category=Minecraft
set EGG_SOURCES[3].Url=https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/forge/egg-forge.json

set EGG_SOURCES[4].Name=CurseForge
set EGG_SOURCES[4].Category=Minecraft
set EGG_SOURCES[4].Url=https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/curseforge/egg-curseforge-generic.json

set EGG_SOURCES[5].Name=BungeeCord
set EGG_SOURCES[5].Category=Minecraft
set EGG_SOURCES[5].Url=https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/bungeecord/egg-bungeecord.json

set EGG_SOURCES[6].Name=Purpur
set EGG_SOURCES[6].Category=Minecraft
set EGG_SOURCES[6].Url=https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/purpur/egg-purpur.json

set EGG_SOURCES[7].Name=Folia
set EGG_SOURCES[7].Category=Minecraft
set EGG_SOURCES[7].Url=https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/folia/egg-folia.json

set EGG_SOURCES[8].Name=NeoForge
set EGG_SOURCES[8].Category=Minecraft
set EGG_SOURCES[8].Url=https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/neoforge/egg-neoforge.json

set EGG_SOURCES[9].Name=Gitea
set EGG_SOURCES[9].Category=Software
set EGG_SOURCES[9].Url=https://raw.githubusercontent.com/pterodactyl/application-eggs/main/gitea/egg-gitea.json

set EGG_SOURCES[10].Name=Uptime-Kuma
set EGG_SOURCES[10].Category=Software
set EGG_SOURCES[10].Url=https://raw.githubusercontent.com/pterodactyl/application-eggs/main/uptime-kuma/egg-uptime-kuma.json

set EGG_SOURCES[11].Name=Grafana
set EGG_SOURCES[11].Category=Software
set EGG_SOURCES[11].Url=https://raw.githubusercontent.com/pterodactyl/application-eggs/main/grafana/egg-grafana.json

set EGG_SOURCES[12].Name=code-server
set EGG_SOURCES[12].Category=Software
set EGG_SOURCES[12].Url=https://raw.githubusercontent.com/pterodactyl/application-eggs/main/code-server/egg-code-server.json

set EGG_SOURCES[13].Name=Lavalink
set EGG_SOURCES[13].Category=Software
set EGG_SOURCES[13].Url=https://raw.githubusercontent.com/pterodactyl/application-eggs/main/lavalink/egg-lavalink.json

set EGG_SOURCES[14].Name=Meilisearch
set EGG_SOURCES[14].Category=Software
set EGG_SOURCES[14].Url=https://raw.githubusercontent.com/pterodactyl/application-eggs/main/meilisearch/egg-meilisearch.json

set EGG_SOURCES[15].Name=Minio
set EGG_SOURCES[15].Category=Storage
set EGG_SOURCES[15].Url=https://raw.githubusercontent.com/pterodactyl/application-eggs/main/minio/egg-minio.json

:: Create output directory
set OUTPUT_DIR=%~dp0..\eggs
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

set DOWNLOADED=0
set SKIPPED=0
set TOTAL=16

for /l %%i in (0,1,15) do (
    :: Check category filter
    if /i "!CATEGORY!"=="All" goto :PROCESS_%%i
    if /i "!CATEGORY!"=="!EGG_SOURCES[%%i].Category!" goto :PROCESS_%%i
    goto :NEXT_%%i

    :PROCESS_%%i
    set EGG_NAME=!EGG_SOURCES[%%i].Name!
    set EGG_URL=!EGG_SOURCES[%%i].Url!
    set EGG_FILE=!OUTPUT_DIR!\!EGG_NAME!.json

    if exist "!EGG_FILE!" (
        echo  [SKIP] !EGG_NAME! already exists
        set /a SKIPPED+=1
        goto :NEXT_%%i
    )

    echo  [DL] Downloading !EGG_NAME!...
    curl -s -o "!EGG_FILE!" "!EGG_URL!" >nul 2>&1
    if !errorlevel! equ 0 (
        echo  [OK] !EGG_NAME! saved
        set /a DOWNLOADED+=1
    ) else (
        echo  [ERR] !EGG_NAME! failed
    )
    :NEXT_%%i
)

echo.
echo  Summary: %DOWNLOADED% downloaded, %SKIPPED% skipped, %TOTAL% total

:: API Import (optional)
if not "!PANEL_URL!"=="" if not "!API_KEY!"=="" (
    echo.
    echo  Importing eggs via API...
    echo  [INFO] API import requires PowerShell. Run this instead:
    echo    .\scripts\Import-PteroEggs.ps1 -ImportToPanel -PanelUrl "!PANEL_URL!" -ApiKey "!API_KEY!"
    echo.
)

echo.
echo  Usage: %~nx0 [--category All^|Minecraft^|Software^|Storage]
echo         %~nx0 --panel-url http://localhost --api-key ptla_...
echo.
pause
exit /b 0

:SHOW_HELP
echo  PteroWindows Egg Importer
echo.
echo  Downloads game server egg definitions from official Pterodactyl repos.
echo.
echo  Usage: %~nx0 [--category CATEGORY] [--panel-url URL] [--api-key KEY]
echo.
echo  Options:
echo    --category CATEGORY  Filter: All, Minecraft, Software, Storage
echo    --panel-url URL      Panel URL for API import (requires --api-key)
echo    --api-key KEY        Application API key
echo.
echo  Examples:
echo    %~nx0
echo    %~nx0 --category Minecraft
echo    %~nx0 --panel-url http://localhost --api-key ptla_abc123
echo.
pause
exit /b 0
