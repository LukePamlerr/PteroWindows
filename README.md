# PteroWindows

> **Pterodactyl Game Panel for Windows** - v1.12.2 / May 15, 2026

[![Validate](https://github.com/your-org/PteroWindows/actions/workflows/deploy.yml/badge.svg)](https://github.com/your-org/PteroWindows/actions/workflows/deploy.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## What is PteroWindows?

PteroWindows deploys the [Pterodactyl Panel](https://github.com/pterodactyl/panel) (v1.12.2) on **Windows** using Docker Desktop. Pterodactyl is a free, open-source game server management panel that lets you host game servers (Minecraft, ARK, CS2, Valheim, etc.) in isolated Docker containers through a beautiful web UI.

Pterodactyl is Linux-native. PteroWindows is the only way to run it on Windows with full functionality.

---

## Architecture

```
                    Windows Host
   ┌─────────────────────────────────────────────────────┐
   │  Docker Desktop                                      │
   │  ┌──────────────┐  ┌──────────┐  ┌──────────────┐   │
   │  │  Panel        │  │  MariaDB  │  │  Redis        │   │
   │  │  (PHP 8.3     │  │  (MySQL   │  │  (Cache/      │   │
   │  │   + Nginx)    │  │   compat) │  │   Queue)      │   │
   │  │  :80/:443     │  │  :3306    │  │  :6379        │   │
   │  └──────┬───────┘  └──────────┘  └──────────────┘   │
   │         │                                            │
   │  WSL2 ──┘                                            │
   │  ┌─────────────────────────────────┐                 │
   │  │  Wings Daemon  +  Docker Engine  │                 │
   │  │  Game Server Containers          │                 │
   │  └─────────────────────────────────┘                 │
   └─────────────────────────────────────────────────────┘
```

---

## Quick Start

### Prerequisites

| Requirement | Version | Download |
|-------------|---------|----------|
| Windows 10/11 | 22H2+ (Pro/Enterprise) | - |
| WSL2 | Any | `wsl --install` (Admin PowerShell) |
| Docker Desktop | 4.x+ | [docker.com](https://docs.docker.com/desktop/install/windows-install/) |
| Git | 2.x+ | [git-scm.com](https://git-scm.com/download/win) |

### Installation

```powershell
# 1. Clone the repository
git clone https://github.com/your-org/PteroWindows.git
cd PteroWindows

# 2. Configure your environment
copy .env.example .env
# Edit .env - set your domain, passwords, timezone

# 3. Install the Panel (Docker)
.\install-panel.ps1

# 4. Install Wings daemon (WSL2)
.\install-wings.ps1
```

That's it. Open **http://localhost** in your browser.

---

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `install-panel.ps1` | Full panel installation (Docker containers, DB, admin user, eggs) |
| `install-wings.ps1` | Wings daemon setup in WSL2 (Docker Engine, Wings binary, service) |
| `update-all.ps1` | Updates panel, wings, and eggs to latest versions |
| `scripts/Import-PteroEggs.ps1` | Download/import game server eggs from community repos |
| `docker-compose.yml` | Docker Compose stack (panel, database, cache) |
| `.env.example` | Environment configuration template |

---

## Detailed Setup Guide

### 1. Panel Installation

```powershell
.\install-panel.ps1 -AutoYes
```

The script will:

1. **Check prerequisites** - Docker, Git, WSL2
2. **Set up directories** - Creates `data/` for persistent storage
3. **Start Docker stack** - Pulls and runs panel, MariaDB, Redis
4. **Initialize panel** - Generates app key, runs migrations
5. **Create admin user** - Prompts for email/username/password
6. **Download eggs** - Fetches game server egg definitions
7. **Print summary** - Login URL and credentials

### 2. Wings Setup (Daemon)

Wings runs inside WSL2 because it requires Linux Docker Engine (not Docker Desktop).

```powershell
.\install-wings.ps1
```

After Wings installs:

1. Log into the panel at `http://localhost`
2. Go to **Admin > Nodes > Create New**
3. Enter:
   - **Name**: `local`
   - **FQDN**: `127.0.0.1`
   - **Public**: Unchecked (if local only)
4. After creation, click the **Configuration** tab
5. Copy the YAML config and save it to `data/wings/config.yml`
6. Restart Wings in WSL:
   ```powershell
   wsl -d Ubuntu -- sudo systemctl restart wings
   ```

### 3. Adding Game Servers

1. In the panel, go to **Servers > Create New**
2. Select a **Node** (the one you created)
3. Select an **Egg** (Minecraft Paper, Spigot, etc.)
4. Allocate resources (CPU, RAM, disk)
5. Start the server from the server console

### 4. Development Mode

Set `APP_ENV=development` in `.env` for debugging.

---

## Docker Compose Services

| Service | Image | Purpose |
|---------|-------|---------|
| `panel` | `ghcr.io/pterodactyl/panel:latest` | Main panel (PHP 8.3 + Nginx) |
| `database` | `mariadb:10.11` | MySQL-compatible database |
| `cache` | `redis:7-alpine` | Session & queue cache |

### Persistent Data

```
data/
├── database/       # MariaDB data files
└── panel/
    ├── var/        # Panel runtime files
    ├── logs/       # Panel logs
    ├── nginx/      # Nginx site configs
    └── certs/      # SSL certificates
```

---

## Eggs

Eggs in the `eggs/` directory:

| Egg | Game/Use | Source |
|-----|----------|--------|
| `egg-paper.json` | Minecraft Paper | [game-eggs](https://github.com/pterodactyl/game-eggs) |
| `egg-spigot.json` | Minecraft Spigot | [game-eggs](https://github.com/pterodactyl/game-eggs) |
| `egg-fabric.json` | Minecraft Fabric | [game-eggs](https://github.com/pterodactyl/game-eggs) |

Run `.\scripts\Import-PteroEggs.ps1` to download all community eggs.

### Egg Sources

All eggs are sourced from the official Pterodactyl repositories:
- **Game eggs**: [pterodactyl/game-eggs](https://github.com/pterodactyl/game-eggs) (Minecraft servers)
- **Application eggs**: [pterodactyl/application-eggs](https://github.com/pterodactyl/application-eggs) (Gitea, Grafana, etc.)
- **All eggs**: [eggs.pterodactyl.io](https://eggs.pterodactyl.io/) (official registry)

---

## Updates

```powershell
.\update-all.ps1
```

This pulls the latest panel Docker image, runs migrations, downloads the latest Wings binary into WSL, and refreshes eggs.

The GitHub Actions workflow also refreshes eggs weekly.

---

## Configuration Reference

### `.env` File

```ini
APP_URL=http://localhost              # Panel URL
APP_TIMEZONE=UTC                      # Server timezone
APP_SERVICE_AUTHOR=admin@example.com  # Footer email
DB_PASSWORD=CHANGE_ME                 # Database user password
DB_ROOT_PASSWORD=CHANGE_ME            # Database root password
HTTP_PORT=80                          # HTTP bind port
HTTPS_PORT=443                        # HTTPS bind port
LE_EMAIL=                             # Let's Encrypt email (for SSL)
MAIL_DRIVER=smtp                      # Mail driver
MAIL_HOST=mail.example.com            # SMTP host
```

### CLI Parameters

| Script | Parameter | Effect |
|--------|-----------|--------|
| `install-panel.ps1` | `-SkipChecks` | Skip prerequisite verification |
| `install-panel.ps1` | `-AutoYes` | Non-interactive mode |
| `install-wings.ps1` | `-WslDistro Ubuntu-24.04` | Use specific WSL distro |
| `install-wings.ps1` | `-AutoYes` | Non-interactive mode |
| `update-all.ps1` | `-SkipPanel` | Skip panel update |
| `update-all.ps1` | `-SkipWings` | Skip wings update |
| `update-all.ps1` | `-SkipEggs` | Skip egg refresh |

---

## Troubleshooting

### Panel won't start

```powershell
docker compose logs panel
```

### Database connection refused

Wait for MariaDB to initialize (30-60s on first run):

```powershell
docker compose logs database
```

### Wings doesn't connect

1. Verify the config in `data/wings/config.yml` matches what the panel shows
2. Check the token_id and token are correct
3. Make sure the panel is accessible from WSL: `wsl -- curl http://localhost`

### Port 80/443 already in use

Edit `.env`:
```ini
HTTP_PORT=8080
HTTPS_PORT=8443
```
Then access `http://localhost:8080`.

### Reset everything

```powershell
docker compose down -v
Remove-Item -Recurse -Force data
.\install-panel.ps1
```

---

## Production Deployment

For production use:

1. Set `APP_URL` to your domain (e.g. `https://panel.yourdomain.com`)
2. Set `LE_EMAIL` for automatic Let's Encrypt SSL certificates
3. Configure DNS to point your domain to the Windows host IP
4. Set strong database passwords (32+ chars)
5. Configure SMTP mail settings for password resets
6. Consider a reverse proxy (nginx on Windows, Cloudflare Tunnel, etc.)

---

## Version Compatibility

| PteroWindows | Panel | Wings | Docker Image |
|-------------|-------|-------|-------------|
| 1.0.0 | v1.12.2 | v1.12.1 | `ghcr.io/pterodactyl/panel:latest` |

---

## License

MIT License - see [LICENSE](LICENSE).

Pterodactyl Panel is [MIT licensed](https://github.com/pterodactyl/panel) (c) Dane Everitt & Contributors.

---

## Disclaimer

Pterodactyl is Linux-native software. PteroWindows provides a Windows deployment wrapper using Docker and WSL2. For production deployments, a Linux server (Ubuntu 24.04 LTS) is recommended.
