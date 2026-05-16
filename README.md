# PteroWindows

> **Pterodactyl Game Panel for Windows** - v1.12.2 / May 15, 2026

[![Validate](https://github.com/LukePamlerr/PteroWindows/actions/workflows/deploy.yml/badge.svg)](https://github.com/LukePamlerr/PteroWindows/actions/workflows/deploy.yml)
[![Release](https://img.shields.io/github/v/release/LukePamlerr/PteroWindows)](https://github.com/LukePamlerr/PteroWindows/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## Download

[**Download latest release**](https://github.com/LukePamlerr/PteroWindows/releases) -- includes all scripts, eggs, and config files in a single `.zip` archive. No compilation or build step needed.

---

## What is PteroWindows?

PteroWindows deploys the [Pterodactyl Panel](https://github.com/pterodactyl/panel) (v1.12.2) on **Windows** using Docker Desktop. Pterodactyl is a free, open-source game server management panel that lets you host game servers (Minecraft, ARK, CS2, Valheim, etc.) in isolated Docker containers through a beautiful web UI.

Pterodactyl is Linux-native. PteroWindows is the only way to run it on Windows with full functionality. All scripts are Windows **batch (.bat)** files -- no PowerShell required.

---

## Quick Start

### Prerequisites

| Requirement | Version | Install |
|-------------|---------|---------|
| Windows 10/11 | 22H2+ (Pro/Enterprise) | -- |
| Docker Desktop | 4.x+ | [download](https://docs.docker.com/desktop/install/windows-install/) |
| WSL2 | any | `wsl --install` (as Admin in CMD) |
| Git | 2.x+ | [download](https://git-scm.com/download/win) |

### One-Command Menu

```batch
git clone https://github.com/LukePamlerr/PteroWindows.git
cd PteroWindows
copy .env.example .env
PteroWindows.bat
```

Select **Option 1** to install the panel, then **Option 2** for Wings.

---

## Menu System

Run `PteroWindows.bat` to open the main menu:

```
  ##############################################################
  #         PteroWindows v1.0.0 - Pterodactyl for Windows      #
  #         Panel v1.12.2 | Wings v1.12.1                      #
  ##############################################################

  1. Install Panel
  2. Install Wings (Daemon via WSL2)
  3. Update Everything
  4. Configure Custom Domain
  5. Download/Import Eggs
  6. View Panel Status
  7. Restart All Services
  8. Stop All Services
  9. View Logs
  0. Exit
```

| Option | What it does |
|--------|-------------|
| **1** | Full panel install: checks prerequisites, creates Docker stack (panel + MariaDB + Redis), generates app key, runs migrations, creates admin user, downloads eggs. Prompts for domain and auto-generates passwords. |
| **2** | Wings daemon install: checks/installs WSL2, installs Docker Engine inside WSL, downloads latest Wings binary, configures systemd service, generates config template. |
| **3** | One-command update: pulls latest panel Docker image, runs DB migrations, updates Wings binary in WSL, refreshes egg files. |
| **4** | Set or change your custom domain. Updates `APP_URL` in `.env`, sets Let's Encrypt email, restarts panel. |
| **5** | Download 18 game/application eggs from official pterodactyl repos. |
| **6** | Shows container status, panel health check, current config, and data disk usage. |
| **7** | Restarts all Docker containers + Wings daemon. |
| **8** | Stops all Docker containers. |
| **9** | View panel, database, or nginx access logs. |

---

## Custom Domain & SSL

Option **4** in the menu configures custom domains:

1. Enter your domain (e.g. `panel.yourdomain.com` or `https://panel.yourdomain.com`)
2. Optionally enter your email for Let's Encrypt SSL
3. The panel restarts with the new domain

### Prerequisites for SSL

- Domain must be public (not `localhost` or a bare IP)
- DNS A record points to this Windows machine
- Ports 80 and 443 are open in Windows Firewall
- Ports 80 and 443 are forwarded from your router (if behind NAT)

### Without SSL

Use `http://localhost` for local testing, or set `APP_URL=http://your.ip.address` for LAN access.

---

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `PteroWindows.bat` | Main menu hub -- launch everything from here |
| `install-panel.bat` | Standalone panel installer |
| `install-wings.bat` | Standalone Wings installer |
| `update-all.bat` | Standalone updater |
| `scripts/import-eggs.bat` | Egg downloader (18 eggs from official repos) |
| `docker-compose.yml` | Docker Compose stack (panel, database, cache) |
| `.env.example` | Environment configuration template |

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

## Persistent Data

```
data/
├── database/       # MariaDB data files
├── panel/
│   ├── var/        # Panel runtime files
│   ├── logs/       # Panel access and error logs
│   ├── nginx/      # Custom nginx site configs
│   └── certs/      # Let's Encrypt SSL certificates
└── wings/          # Wings daemon config.yml
```

---

## Eggs

Shipped eggs (in `eggs/`):

| File | Type | Source |
|------|------|--------|
| `egg-paper.json` | Minecraft Paper | [game-eggs](https://github.com/pterodactyl/game-eggs) |
| `egg-spigot.json` | Minecraft Spigot | [game-eggs](https://github.com/pterodactyl/game-eggs) |
| `egg-fabric.json` | Minecraft Fabric | [game-eggs](https://github.com/pterodactyl/game-eggs) |

Run `scripts\import-eggs.bat` to download 18 eggs including Forge, Purpur, Folia, BungeeCord, NeoForge, Gitea, Grafana, and more.

Sources: [game-eggs](https://github.com/pterodactyl/game-eggs) | [application-eggs](https://github.com/pterodactyl/application-eggs) | [eggs.pterodactyl.io](https://eggs.pterodactyl.io/)

---

## Updates

Menu **Option 3** or:
```batch
update-all.bat
```

Pulls latest panel Docker image, runs migrations, updates Wings binary, refreshes eggs.

GitHub Actions also refreshes eggs weekly via `.github/workflows/update-eggs.yml`.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Panel won't start | `docker compose logs panel` |
| DB connection refused | Wait 30-60s for MariaDB init |
| Port 80/443 in use | Edit `.env`: `HTTP_PORT=8080`, `HTTPS_PORT=8443` |
| Wings won't connect | Verify `data/wings/config.yml` matches panel node config |
| WSL not found | Run `wsl --install` as Admin |
| Reset everything | `docker compose down -v` + `rmdir /s /q data` + reinstall |

---

## File Manifest

```
PteroWindows/
├── PteroWindows.bat            # Main menu (launch this)
├── install-panel.bat           # Panel installer
├── install-wings.bat           # Wings daemon installer
├── update-all.bat              # Auto-updater
├── docker-compose.yml          # Docker stack
├── .env.example                # Config template
├── .gitignore
├── LICENSE
├── README.md
├── eggs/
│   ├── egg-paper.json
│   ├── egg-spigot.json
│   └── egg-fabric.json
├── scripts/
│   └── import-eggs.bat
└── .github/workflows/
    ├── deploy.yml
    └── update-eggs.yml
```

---

## License

MIT License. Pterodactyl Panel is (c) Dane Everitt & Contributors, MIT licensed.

---

## Disclaimer

Pterodactyl is Linux-native software. PteroWindows provides a Windows deployment wrapper using Docker and WSL2. For production at scale, a Linux server (Ubuntu 24.04 LTS) is recommended.
