# PteroWindows

> **Pterodactyl Game Panel for Windows** - v1.12.2 / May 15, 2026

[![Validate](https://github.com/LukePamlerr/PteroWindows/actions/workflows/deploy.yml/badge.svg)](https://github.com/LukePamlerr/PteroWindows/actions/workflows/deploy.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## What is PteroWindows?

PteroWindows deploys the [Pterodactyl Panel](https://github.com/pterodactyl/panel) (v1.12.2) on **Windows** using Docker Desktop. Pterodactyl is a free, open-source game server management panel that lets you host game servers (Minecraft, ARK, CS2, Valheim, etc.) in isolated Docker containers through a beautiful web UI.

Pterodactyl is Linux-native. PteroWindows is the only way to run it on Windows with full functionality. All scripts are Windows **batch (.bat)** files -- no PowerShell required.

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
| WSL2 | Any | Run `wsl --install` as Admin in CMD |
| Docker Desktop | 4.x+ | [docker.com](https://docs.docker.com/desktop/install/windows-install/) |
| Git | 2.x+ | [git-scm.com](https://git-scm.com/download/win) |

Run everything from **Command Prompt (CMD)** -- NOT PowerShell.

### Installation

```batch
:: 1. Clone the repository
git clone https://github.com/LukePamlerr/PteroWindows.git
cd PteroWindows

:: 2. Configure your environment
copy .env.example .env
:: Edit .env - set your domain, passwords, timezone

:: 3. Install the Panel (Docker)
install-panel.bat

:: 4. Install Wings daemon (WSL2)
install-wings.bat
```

That's it. Open **http://localhost** in your browser.

---

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `install-panel.bat` | Full panel installation (Docker containers, DB, admin user, eggs) |
| `install-wings.bat` | Wings daemon setup in WSL2 (Docker Engine, Wings binary, service) |
| `update-all.bat` | Updates panel, wings, and eggs to latest versions |
| `scripts/import-eggs.bat` | Download/import game server eggs from community repos |
| `docker-compose.yml` | Docker Compose stack (panel, database, cache) |
| `.env.example` | Environment configuration template |

---

## Detailed Setup Guide

### 1. Panel Installation

```batch
install-panel.bat
```

The script will:

1. **Check prerequisites** - Docker, Git, WSL2
2. **Set up directories** - Creates `data/` for persistent storage
3. **Start Docker stack** - Pulls and runs panel, MariaDB, Redis
4. **Initialize panel** - Generates app key, runs migrations
5. **Create admin user** - Prompts for email/username/password
6. **Download eggs** - Fetches game server egg definitions from official repos
7. **Print summary** - Login URL and credentials

### 2. Wings Setup (Daemon)

Wings runs inside WSL2 because it requires Linux Docker Engine (not Docker Desktop).

```batch
install-wings.bat
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
   ```batch
   wsl -d Ubuntu-22.04 -- sudo systemctl restart wings
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

Eggs shipped in the `eggs/` directory:

| Egg | Game/Use | Source |
|-----|----------|--------|
| `egg-paper.json` | Minecraft Paper | [game-eggs](https://github.com/pterodactyl/game-eggs) |
| `egg-spigot.json` | Minecraft Spigot | [game-eggs](https://github.com/pterodactyl/game-eggs) |
| `egg-fabric.json` | Minecraft Fabric | [game-eggs](https://github.com/pterodactyl/game-eggs) |

Run `scripts\import-eggs.bat` to download all community eggs (includes Forge, BungeeCord, Purpur, Folia, NeoForge, Gitea, Grafana, and more).

### Egg Sources

All eggs are sourced from the official Pterodactyl repositories:
- **Game eggs**: [pterodactyl/game-eggs](https://github.com/pterodactyl/game-eggs) (Minecraft servers)
- **Application eggs**: [pterodactyl/application-eggs](https://github.com/pterodactyl/application-eggs) (Gitea, Grafana, etc.)
- **All eggs**: [eggs.pterodactyl.io](https://eggs.pterodactyl.io/) (official registry)

---

## Updates

```batch
update-all.bat
```

This pulls the latest panel Docker image, runs migrations, downloads the latest Wings binary into WSL, and refreshes eggs.

The GitHub Actions workflow (`update-eggs.yml`) also refreshes eggs weekly.

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

---

## Troubleshooting

### Panel won't start

```batch
docker compose logs panel
```

### Database connection refused

Wait for MariaDB to initialize (30-60s on first run):

```batch
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

```batch
docker compose down -v
rmdir /s /q data
install-panel.bat
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

## File Manifest

```
PteroWindows/
├── install-panel.bat         # Main panel installer (CMD batch)
├── install-wings.bat         # Wings daemon installer (CMD batch)
├── update-all.bat            # Auto-updater (CMD batch)
├── docker-compose.yml        # Docker stack (panel + database + cache)
├── .env.example              # Environment configuration template
├── .gitignore
├── LICENSE                   # MIT License
├── README.md                 # This file
├── eggs/
│   ├── egg-paper.json        # Minecraft Paper server egg
│   ├── egg-spigot.json       # Minecraft Spigot server egg
│   └── egg-fabric.json       # Minecraft Fabric server egg
├── scripts/
│   └── import-eggs.bat       # Egg downloader/importer (CMD batch)
└── .github/workflows/
    ├── deploy.yml            # CI validation + release builder
    └── update-eggs.yml       # Weekly egg refresh
```

---

## License

MIT License - see [LICENSE](LICENSE).

Pterodactyl Panel is [MIT licensed](https://github.com/pterodactyl/panel) (c) Dane Everitt & Contributors.

---

## Disclaimer

Pterodactyl is Linux-native software. PteroWindows provides a Windows deployment wrapper using Docker and WSL2. For production deployments, a Linux server (Ubuntu 24.04 LTS) is recommended.
