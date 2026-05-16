# PteroWindows

> **Pterodactyl Game Panel for Windows** — v2.0.0 / Desktop App

[![Validate](https://github.com/LukePamlerr/PteroWindows/actions/workflows/deploy.yml/badge.svg)](https://github.com/LukePamlerr/PteroWindows/actions/workflows/deploy.yml)
[![Release](https://img.shields.io/github/v/release/LukePamlerr/PteroWindows)](https://github.com/LukePamlerr/PteroWindows/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## Download

[**Download latest release**](https://github.com/LukePamlerr/PteroWindows/releases) — Windows desktop app (`.exe` installer) or the original `.bat` scripts archive.

---

## What is PteroWindows?

PteroWindows deploys the [Pterodactyl Panel](https://github.com/pterodactyl/panel) (v1.12.2) on **Windows** using Docker Desktop. Pterodactyl is a free, open-source game server management panel that lets you host game servers (Minecraft, ARK, CS2, Valheim, etc.) in isolated Docker containers through a beautiful web UI.

PteroWindows v2.0.0 is a **Windows desktop application** built with Electron, featuring a dark black & blue UI, real-time command output, and all management tools in one window.

---

## Quick Start

### Prerequisites

| Requirement | Version | Install |
|-------------|---------|---------|
| Windows 10/11 | 22H2+ (Pro/Enterprise) | -- |
| Docker Desktop | 4.x+ | [download](https://docs.docker.com/desktop/install/windows-install/) |
| WSL2 | any | `wsl --install` (as Admin in CMD) |
| Git | 2.x+ | [download](https://git-scm.com/download/win) |

### Desktop App

```
git clone https://github.com/LukePamlerr/PteroWindows.git
cd PteroWindows
copy .env.example .env
npm start
```

### Batch Scripts (fallback)

```batch
PteroWindows.bat
```

---

## Features

- **Desktop UI** — Modern black & blue interface with real-time command output
- **Panel Installer** — Full Docker stack (panel + MariaDB + Redis), app key generation, migrations, admin user creation, egg downloads
- **Wings Installer** — WSL2 + Docker Engine + Wings daemon in Ubuntu
- **One-Click Update** — Pulls latest images, runs migrations, updates Wings, refreshes eggs
- **Custom Domain & SSL** — Set `APP_URL`, `LE_EMAIL`, restart panel with new domain
- **Egg Importer** — 18 game/application eggs from official Pterodactyl repos
- **Status Dashboard** — Real-time panel health, Docker status, container info, env config
- **Log Viewer** — Panel, database, and nginx logs in-app

---

## Menu Reference

| Action | Description |
|--------|-------------|
| **Dashboard** | At-a-glance status of Docker, Panel, Wings, Eggs, and environment |
| **Install Panel** | Full panel deployment with options for domain, email, admin credentials |
| **Install Wings** | Wings daemon via WSL2 — Docker Engine, binary, systemd service |
| **Update** | Pull latest images, run migrations, update Wings binary, refresh eggs |
| **Domain Config** | Set custom domain, Let's Encrypt email, restart panel |
| **Eggs** | Download 18 eggs from official pterodactyl/game-eggs and application-eggs |
| **Status** | Container status, health check, env configuration, disk usage |
| **Restart** | Restart all Docker containers + Wings daemon |
| **Stop** | Stop all Docker containers |
| **Logs** | View panel, database, or nginx logs |

---

## Architecture

```
                    Windows Host
   ┌─────────────────────────────────────────────────────┐
   │  PteroWindows Desktop App (Electron)                  │
   │  ┌─────────────────────────────────────────────────┐  │
   │  │  Docker Desktop                                  │  │
   │  │  ┌──────────────┐  ┌──────────┐  ┌────────────┐  │  │
   │  │  │  Panel        │  │  MariaDB  │  │  Redis      │  │  │
   │  │  │  (PHP 8.3     │  │  (MySQL   │  │  (Cache/    │  │  │
   │  │  │   + Nginx)    │  │   compat) │  │   Queue)    │  │  │
   │  │  │  :80/:443     │  │  :3306    │  │  :6379      │  │  │
   │  │  └──────┬───────┘  └──────────┘  └────────────┘  │  │
   │  │         │                                          │  │
   │  │  WSL2 ──┘                                          │  │
   │  │  ┌─────────────────────────────────┐               │  │
   │  │  │  Wings Daemon  +  Docker Engine  │               │  │
   │  │  │  Game Server Containers          │               │  │
   │  │  └─────────────────────────────────┘               │  │
   │  └─────────────────────────────────────────────────────┘  │
   └──────────────────────────────────────────────────────────┘
```

---

## Development

```bash
# Run in development
npm start

# Package for distribution
npm run build
```

The app is built with:
- **Electron** — Cross-platform desktop shell
- **Node.js** — System command execution (Docker, WSL, PowerShell)
- **Vanilla JS** — No frameworks, lightweight UI
- **CSS** — Dark theme with black & blue color scheme

Batch scripts (`*.bat`) remain as a fallback for headless/CI environments.

---

## Custom Domain & SSL

Configure a custom domain from the **Domain Config** section:

1. Enter your domain (e.g. `panel.yourdomain.com`)
2. Optionally enter your email for Let's Encrypt SSL
3. Click **Apply Domain** — the panel restarts with the new domain

### Prerequisites for SSL

- Public domain (not `localhost` or bare IP)
- DNS A record points to this Windows machine
- Ports 80 and 443 open in Windows Firewall
- Ports 80 and 443 forwarded from router (if behind NAT)

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Panel won't start | Check **Logs** > Panel Log, or run `docker compose logs panel` |
| DB connection refused | Wait 30-60s for MariaDB init |
| Port 80/443 in use | Edit `.env`: `HTTP_PORT=8080`, `HTTPS_PORT=8443` |
| Wings won't connect | Verify `data/wings/config.yml` matches panel node config |
| WSL not found | Run `wsl --install` as Admin |
| Reset everything | `docker compose down -v` + `rmdir /s /q data` + reinstall |

---

## File Manifest

```
PteroWindows/
├── main.js                     # Electron main process
├── preload.js                  # Context bridge (IPC)
├── renderer/
│   ├── index.html              # Desktop UI
│   ├── styles.css              # Black & blue theme
│   └── app.js                  # Frontend logic
├── package.json                # Node.js manifest
├── PteroWindows.bat            # Batch menu (fallback)
├── install-panel.bat           # Panel installer (fallback)
├── install-wings.bat           # Wings installer (fallback)
├── update-all.bat              # Updater (fallback)
├── docker-compose.yml          # Docker stack
├── .env.example                # Config template
├── .gitignore
├── LICENSE
├── README.md
├── eggs/                       # Game server eggs
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
