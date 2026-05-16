<#
.SYNOPSIS
    Downloads and imports Pterodactyl eggs from community repositories.
.DESCRIPTION
    Fetches updated egg JSON definitions for popular games and software.
    Can import them directly into the panel via the API.
.PARAMETER EggCategory
    Filter by category: Games, Software, Minecraft, All (default: All).
.PARAMETER ImportToPanel
    Import eggs into the panel via API (requires API key).
.PARAMETER PanelUrl
    Panel URL for API import.
.PARAMETER ApiKey
    Pterodactyl API key (Admin > Application API).
.PARAMETER OutputDir
    Directory to save egg files (default: ./eggs).
.EXAMPLE
    .\scripts\Import-PteroEggs.ps1
    .\scripts\Import-PteroEggs.ps1 -EggCategory Minecraft
    .\scripts\Import-PteroEggs.ps1 -ImportToPanel -PanelUrl http://localhost -ApiKey "ptla_..."
#>

[CmdletBinding()]
param(
    [ValidateSet("All", "Games", "Minecraft", "Software", "Voice", "Storage")]
    [string]$EggCategory = "All",
    [switch]$ImportToPanel,
    [string]$PanelUrl = "http://localhost",
    [string]$ApiKey = "",
    [string]$OutputDir = ""
)

$ErrorActionPreference = "SilentlyContinue"

if (-not $OutputDir) {
    $OutputDir = Join-Path $PSScriptRoot "..\eggs"
}
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$eggSources = @(
    @{ Name = "Paper"; Category = "Minecraft"; Url = "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/paper/egg-paper.json" }
    @{ Name = "Spigot"; Category = "Minecraft"; Url = "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/spigot/egg-spigot.json" }
    @{ Name = "Fabric"; Category = "Minecraft"; Url = "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/fabric/egg-fabric.json" }
    @{ Name = "Forge"; Category = "Minecraft"; Url = "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/forge/egg-forge.json" }
    @{ Name = "CurseForge"; Category = "Minecraft"; Url = "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/curseforge/egg-curseforge-generic.json" }
    @{ Name = "BungeeCord"; Category = "Minecraft"; Url = "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/bungeecord/egg-bungeecord.json" }
    @{ Name = "Purpur"; Category = "Minecraft"; Url = "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/purpur/egg-purpur.json" }
    @{ Name = "Folia"; Category = "Minecraft"; Url = "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/folia/egg-folia.json" }
    @{ Name = "NeoForge"; Category = "Minecraft"; Url = "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/neoforge/egg-neoforge.json" }
    @{ Name = "Magma"; Category = "Minecraft"; Url = "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/magma/egg-magma.json" }
    @{ Name = "VanillaCord"; Category = "Minecraft"; Url = "https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/vanillacord/egg-vanilla-cord.json" }
    @{ Name = "Gitea"; Category = "Software"; Url = "https://raw.githubusercontent.com/pterodactyl/application-eggs/main/gitea/egg-gitea.json" }
    @{ Name = "Uptime-Kuma"; Category = "Software"; Url = "https://raw.githubusercontent.com/pterodactyl/application-eggs/main/uptime-kuma/egg-uptime-kuma.json" }
    @{ Name = "Grafana"; Category = "Software"; Url = "https://raw.githubusercontent.com/pterodactyl/application-eggs/main/grafana/egg-grafana.json" }
    @{ Name = "code-server"; Category = "Software"; Url = "https://raw.githubusercontent.com/pterodactyl/application-eggs/main/code-server/egg-code-server.json" }
    @{ Name = "Lavalink"; Category = "Software"; Url = "https://raw.githubusercontent.com/pterodactyl/application-eggs/main/lavalink/egg-lavalink.json" }
    @{ Name = "Meilisearch"; Category = "Software"; Url = "https://raw.githubusercontent.com/pterodactyl/application-eggs/main/meilisearch/egg-meilisearch.json" }
    @{ Name = "Minio"; Category = "Storage"; Url = "https://raw.githubusercontent.com/pterodactyl/application-eggs/main/minio/egg-minio.json" }
    @{ Name = "Elasticsearch"; Category = "Software"; Url = "https://raw.githubusercontent.com/pterodactyl/application-eggs/main/elasticsearch/egg-elasticsearch.json" }
)

Write-Host "PteroWindows Egg Importer" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host ""

$selectedEggs = if ($EggCategory -eq "All") { $eggSources } else { $eggSources | Where-Object { $_.Category -eq $EggCategory } }

$downloaded = 0
$skipped = 0

foreach ($egg in $selectedEggs) {
    $eggFile = Join-Path $OutputDir "$($egg.Name).json"

    if (Test-Path $eggFile) {
        Write-Host "  [SKIP] $($egg.Name) already exists" -ForegroundColor Gray
        $skipped++
        continue
    }

    Write-Host "  [DL]   $($egg.Name)..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $egg.Url -OutFile $eggFile -UseBasicParsing -TimeoutSec 30
        Write-Host "  [OK]   $($egg.Name) saved" -ForegroundColor Green
        $downloaded++
    } catch {
        Write-Host "  [ERR]  $($egg.Name): $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Summary: $downloaded downloaded, $skipped skipped, $($selectedEggs.Count) total" -ForegroundColor Cyan

if ($ImportToPanel) {
    Write-Host ""
    Write-Host "Importing eggs via API..." -ForegroundColor Yellow

    if (-not $ApiKey) {
        $ApiKey = Read-Host "  Enter Application API key (ptla_...) "
    }

    $eggsToImport = Get-ChildItem $OutputDir -Filter "*.json"
    $imported = 0

    foreach ($eggFile in $eggsToImport) {
        try {
            $eggData = Get-Content $eggFile -Raw | ConvertFrom-Json

            $body = @{
                name        = $eggData.name
                description = $eggData.description
                author      = "import@script"
                uuid        = [guid]::NewGuid().ToString()
            } | ConvertTo-Json

            $headers = @{
                "Authorization" = "Bearer $ApiKey"
                "Content-Type"  = "application/json"
                "Accept"        = "application/json"
            }

            $response = Invoke-RestMethod -Uri "$PanelUrl/api/application/eggs" `
                -Method Post `
                -Headers $headers `
                -Body $body `
                -UseBasicParsing

            Write-Host "  [OK]   $($eggFile.BaseName) imported" -ForegroundColor Green
            $imported++
        } catch {
            Write-Host "  [ERR]  $($eggFile.BaseName): $_" -ForegroundColor Red
        }
    }

    Write-Host "  API Import: $imported / $($eggsToImport.Count) eggs imported" -ForegroundColor Cyan
}
