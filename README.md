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

## Custom Domain & SSL — Complete Setup Guide

This guide walks you through making your Pterodactyl panel accessible via a real domain with SSL. You can also use the **Domain Config** section in the desktop app, which has built-in DNS, firewall, port, and SSL verification tools (no guesswork).

### Step 1: Get a Domain Name

You need a domain you control. Buy one from any registrar:

- [Namecheap](https://namecheap.com)
- [GoDaddy](https://godaddy.com)
- [Cloudflare](https://cloudflare.com) (also provides DNS hosting)
- [Google Domains](https://domains.google)

A subdomain like `panel.yourdomain.com` is recommended.

### Step 2: Point DNS to Your Machine

In your DNS provider's dashboard, add an **A record**:

| Field   | Value                          |
|---------|--------------------------------|
| Type    | `A`                            |
| Name    | `panel`                        |
| Value   | *(your Windows machine's public IP)* |
| TTL     | `300` (5 min — or lowest available) |

This creates `panel.yourdomain.com` → `your.public.ip`.

**How to find your public IP:**
- Use the **Detect my IP** button in the app's Domain Config section
- Or visit [api.ipify.org](https://api.ipify.org) in a browser
- Or run: `curl ifconfig.me` in a terminal

**How to find your local IP** (needed for port forwarding):
- Run `ipconfig` in Command Prompt
- Look for "IPv4 Address" under your active network adapter (e.g. `192.168.1.100`)

> DNS propagation can take **5–30 minutes** (sometimes hours). The app's **Check DNS** button confirms when it resolves to your machine.

### Step 3: Verify DNS Resolution

Use the **Check DNS** button in the app (Domain Config section) — it resolves the domain and compares it to your machine's local and public IPs.

Or verify manually:
```cmd
nslookup panel.yourdomain.com
```
The response should show your public IP.

### Step 4: Open Windows Firewall Ports

Allow inbound connections on ports 80 (HTTP) and 443 (HTTPS):

```cmd
netsh advfirewall firewall add rule name="PteroWindows HTTP" dir=in action=allow protocol=TCP localport=80
netsh advfirewall firewall add rule name="PteroWindows HTTPS" dir=in action=allow protocol=TCP localport=443
```

Use the **Check Firewall Rules** button in the app to confirm they're active.

### Step 5: Forward Ports on Your Router

If your Windows machine is behind a router (most home networks), log into your router's admin panel and forward ports:

| External Port | Internal Port | Protocol | Internal IP         |
|---------------|---------------|----------|---------------------|
| 80            | 80            | TCP      | 192.168.1.x (your machine) |
| 443           | 443           | TCP      | 192.168.1.x (your machine) |

**How to find your router's admin page:** Usually `http://192.168.1.1` or `http://192.168.0.1`. Check your router's manual.

### Step 6: Test Port Reachability

Use the **Check Ports** button in the app — it tests whether ports 80 and 443 are reachable from the internet by attempting a TCP connection to your domain.

Or test manually from an external network/phone:
```
https://www.yougetsignal.com/tools/open-ports/
```

> Both ports must be open for Let's Encrypt to issue an SSL certificate. Port 80 is used for the ACME HTTP challenge.

### Step 7: Apply the Domain to PteroWindows

In the app's **Domain Config** section:

1. Enter your domain (e.g. `panel.yourdomain.com`)
2. Enter your email for Let's Encrypt SSL notifications
3. Click **Apply Domain**

The app will:
- Update `APP_URL` in `.env` to `https://panel.yourdomain.com`
- Set `LE_EMAIL` in `.env`
- Restart the panel container with the new domain
- Let's Encrypt will automatically detect ports 80/443 and provision an SSL certificate (this happens inside the nginx container via Certbot, no manual action needed)

To verify the changes took effect:
```cmd
findstr "APP_URL LE_EMAIL" .env
```

### Step 8: Verify SSL Certificate

Use the **Check SSL Certificate** button in the app — it connects via HTTPS and validates the certificate, showing the issuer, subject, and expiration date.

Or visit `https://panel.yourdomain.com` in a browser. A valid Let's Encrypt certificate should be active. If you see a security warning, wait a few minutes and restart the panel:
```cmd
docker compose restart panel
```

### Without SSL (Local / LAN Only)

For local testing or LAN-only access, skip steps 4–6 and use:
- `http://localhost` — panel on the same machine
- `http://192.168.1.x` — panel accessible within your local network (set `APP_URL` to this)

No email or SSL is needed. Ports 80 and 443 remain closed.

### DNS Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Domain doesn't resolve | DNS not propagated | Wait 5–30 min, check with `nslookup` |
| Wrong IP resolves | Old DNS cache | Run `ipconfig /flushdns`, wait for propagation |
| Port check times out | Port not forwarded | Check router port forwarding rules |
| Port check times out | Firewall blocking | Run the `netsh` commands above |
| SSL not provisioning | Port 80 not open | Let's Encrypt needs port 80 for the HTTP challenge |
| SSL not provisioning | Domain not pointing to this IP | Verify DNS A record |
| Panel shows "ERR_SSL_UNRECOGNIZED_NAME_ALGORITHM" | Old browser | Update browser or use incognito mode |

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
