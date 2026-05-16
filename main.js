const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const { spawn, exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const https = require('https');
const dns = require('dns');
const net = require('net');
const os = require('os');

let mainWindow;

const APP_DIR = __dirname;
const ENV_PATH = path.join(APP_DIR, '.env');
const ENV_EXAMPLE = path.join(APP_DIR, '.env.example');
const COMPOSE_FILE = path.join(APP_DIR, 'docker-compose.yml');
const EGGS_DIR = path.join(APP_DIR, 'eggs');
const SCRIPTS_DIR = path.join(APP_DIR, 'scripts');
const DATA_DIR = path.join(APP_DIR, 'data');

function sendOutput(data) {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('cmd:output', data);
  }
}

function sendStatus(status) {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('cmd:status', status);
  }
}

function spawnCommand(event, cmd, args, options) {
  return new Promise((resolve, reject) => {
    const proc = spawn(cmd, args, { ...options, windowsHide: true });
    const send = event ? (d) => event.sender.send('cmd:output', d) : sendOutput;
    proc.stdout.on('data', (data) => send(data.toString()));
    proc.stderr.on('data', (data) => send(data.toString()));
    proc.on('error', (err) => { send(`[ERROR] ${err.message}\n`); reject(err); });
    proc.on('close', (code) => {
      send(`\n[EXIT CODE: ${code}]\n`);
      if (code === 0) resolve(code); else reject(new Error(`Exit code: ${code}`));
    });
  });
}

function execPromise(cmd) {
  return new Promise((resolve, reject) => {
    exec(cmd, { cwd: APP_DIR }, (err, stdout, stderr) => {
      if (err) reject(err); else resolve(stdout.trim());
    });
  });
}

function readEnvFile() {
  try {
    if (!fs.existsSync(ENV_PATH)) return {};
    const content = fs.readFileSync(ENV_PATH, 'utf8');
    const vars = {};
    content.split('\n').forEach(line => {
      const trimmed = line.trim();
      if (trimmed && !trimmed.startsWith('#')) {
        const eqIdx = trimmed.indexOf('=');
        if (eqIdx > 0) vars[trimmed.substring(0, eqIdx).trim()] = trimmed.substring(eqIdx + 1).trim();
      }
    });
    return vars;
  } catch { return {}; }
}

function writeEnvVar(key, value) {
  let content = '';
  let found = false;
  if (fs.existsSync(ENV_PATH)) {
    content = fs.readFileSync(ENV_PATH, 'utf8');
    const lines = content.split('\n').map(l => {
      if (l.trim().startsWith(key + '=')) { found = true; return `${key}=${value}`; }
      return l;
    });
    if (!found) lines.push(`${key}=${value}`);
    content = lines.join('\n');
  } else if (fs.existsSync(ENV_EXAMPLE)) {
    content = fs.readFileSync(ENV_EXAMPLE, 'utf8') + `\n${key}=${value}\n`;
  } else {
    content = `${key}=${value}\n`;
  }
  fs.writeFileSync(ENV_PATH, content, 'utf8');
}

function downloadFile(url, dest) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(dest);
    https.get(url, { headers: { 'User-Agent': 'PteroWindows/1.1.1' } }, (res) => {
      if (res.statusCode === 302 || res.statusCode === 301) {
        file.close(); fs.unlinkSync(dest);
        return downloadFile(res.headers.location, dest).then(resolve).catch(reject);
      }
      if (res.statusCode !== 200) {
        file.close(); fs.unlinkSync(dest);
        return reject(new Error(`HTTP ${res.statusCode}`));
      }
      res.pipe(file);
      file.on('finish', () => { file.close(); resolve(); });
    }).on('error', (err) => { file.close(); if (fs.existsSync(dest)) fs.unlinkSync(dest); reject(err); });
  });
}

function generatePassword() {
  return new Promise((resolve) => {
    const proc = spawn('powershell', [
      '-command', '[System.Convert]::ToBase64String((1..24|%{Get-Random -Max 256}))'
    ], { windowsHide: true });
    let out = '';
    proc.stdout.on('data', d => out += d.toString());
    proc.on('close', () => resolve(out.trim() || 'PteroGenPass2026!'));
  });
}

function findComposeCmd() {
  return new Promise((resolve) => {
    exec('docker compose version', { cwd: APP_DIR }, (err) => {
      if (!err) return resolve('docker compose');
      exec('docker-compose --version', { cwd: APP_DIR }, (err2) => {
        resolve(err2 ? null : 'docker-compose');
      });
    });
  });
}

function setupIPC() {

  ipcMain.handle('docker:check', async () => {
    try {
      await execPromise('docker info');
      let composeCmd = await findComposeCmd();
      return { installed: true, running: true, compose: composeCmd };
    } catch {
      try {
        await execPromise('where docker');
        return { installed: true, running: false, compose: null };
      } catch {
        return { installed: false, running: false, compose: null };
      }
    }
  });

  ipcMain.handle('env:read', async () => readEnvFile());

  ipcMain.handle('env:save', async (_, key, value) => {
    writeEnvVar(key, value);
    return { success: true };
  });

  ipcMain.handle('password:generate', async () => {
    return await generatePassword();
  });

  ipcMain.handle('panel:install', async (event, config) => {
    const send = (d) => event.sender.send('cmd:output', d);
    try {
      send('=== PTERODACTYL PANEL INSTALLATION ===\n\n');

      let dockerCheck;
      try {
        await execPromise('docker info');
        dockerCheck = true;
        send('[OK] Docker is running\n');
      } catch {
        send('[FAIL] Docker Desktop is not running. Please start Docker Desktop first.\n');
        return { success: false, error: 'Docker not running' };
      }

      let composeCmd = await findComposeCmd();
      if (!composeCmd) {
        send('[FAIL] Docker Compose not available.\n');
        return { success: false, error: 'Compose not available' };
      }
      send(`[OK] Using: ${composeCmd}\n\n`);

      if (!fs.existsSync(ENV_PATH)) {
        if (fs.existsSync(ENV_EXAMPLE)) {
          fs.copyFileSync(ENV_EXAMPLE, ENV_PATH);
          send('[INFO] Created .env from .env.example\n');
        } else {
          send('[FAIL] .env.example not found.\n');
          return { success: false, error: 'Missing .env.example' };
        }
      } else {
        send('[OK] .env found\n');
      }

      if (config.domain) {
        let url = config.domain;
        if (!url.startsWith('http://') && !url.startsWith('https://')) url = `https://${url}`;
        writeEnvVar('APP_URL', url);
        send(`[OK] APP_URL set to ${url}\n`);
        if (config.email) {
          writeEnvVar('LE_EMAIL', config.email);
          send(`[OK] LE_EMAIL set to ${config.email}\n`);
        }
      }

      if (config.generatePasswords) {
        send('[INFO] Generating database passwords...\n');
        const dbPass = await generatePassword();
        const rootPass = await generatePassword();
        writeEnvVar('DB_PASSWORD', dbPass);
        writeEnvVar('DB_ROOT_PASSWORD', rootPass);
        send(`[OK] DB_PASSWORD generated\n`);
        send(`[OK] DB_ROOT_PASSWORD generated\n`);
      }

      send('\n[2] Creating data directories...\n');
      const dirs = ['database', 'panel/var', 'panel/logs', 'panel/nginx', 'panel/certs'];
      dirs.forEach(d => { const p = path.join(DATA_DIR, d); if (!fs.existsSync(p)) fs.mkdirSync(p, { recursive: true }); });
      if (!fs.existsSync(EGGS_DIR)) fs.mkdirSync(EGGS_DIR);
      send('[OK] Directories created\n');

      send('\n[3] Pulling Docker images...\n');
      try {
        const output = await execPromise(`"${composeCmd}" pull`);
        send(output + '\n');
        send('[OK] Images pulled\n');
      } catch (e) {
        send(`[WARN] Pull failed: ${e.message}\n`);
      }

      send('\n[4] Starting containers...\n');
      try {
        const output = await execPromise(`"${composeCmd}" up -d`);
        send(output + '\n');
        send('[OK] Containers started\n');
      } catch (e) {
        send(`[FAIL] Failed to start containers: ${e.message}\n`);
        try {
          const logs = await execPromise(`"${composeCmd}" logs panel`);
          send(logs + '\n');
        } catch {}
        return { success: false, error: 'Container start failed' };
      }

      send('\n[5] Waiting for panel to become ready...\n');
      let ready = false;
      for (let i = 0; i < 30; i++) {
        await new Promise(r => setTimeout(r, 3000));
        send('.');
        try {
          await execPromise('curl -s http://localhost/api/health');
          ready = true; break;
        } catch {}
      }
      send(ready ? '\n[OK] Panel is responding\n' : '\n[WARN] Panel not responding yet\n');

      send('\n[6] Initializing panel...\n');
      send('[INFO] Generating application key...\n');
      try {
        await execPromise(`"${composeCmd}" exec -T panel php artisan key:generate --force`);
      } catch (e) { send(`[WARN] Key generation: ${e.message}\n`); }

      send('[INFO] Running database migrations...\n');
      try {
        await execPromise(`"${composeCmd}" exec -T panel php artisan migrate --seed --force`);
        send('[OK] Database ready\n');
      } catch (e) {
        send(`[FAIL] Migration failed: ${e.message}\n`);
        return { success: false, error: 'Migration failed' };
      }

      send('\n[7] Creating admin user...\n');
      let envVars = readEnvFile();
      let panelUrl = envVars.APP_URL || 'http://localhost';
      if (config.adminEmail && config.adminUsername) {
        const adminPass = config.adminPassword || await generatePassword();
        try {
          await execPromise(
            `"${composeCmd}" exec -T panel php artisan p:user:make ` +
            `--email="${config.adminEmail}" --username="${config.adminUsername}" ` +
            `--name="Administrator" --password="${adminPass}" --admin=1`
          );
          send(`[OK] Admin user created\n`);
          send(`\n  URL:      ${panelUrl}\n`);
          send(`  Email:    ${config.adminEmail}\n`);
          send(`  Username: ${config.adminUsername}\n`);
          send(`  Password: ${adminPass}\n`);
        } catch (e) {
          send(`[WARN] Admin creation: ${e.message}\n`);
        }
      } else {
        send('[SKIP] No admin credentials provided. Create one via the panel web UI.\n');
      }

      send('\n[8] Downloading game server eggs...\n');
      const eggs = [
        ['Paper', 'https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/paper/egg-paper.json'],
        ['Spigot', 'https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/spigot/egg-spigot.json'],
        ['Fabric', 'https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/fabric/egg-fabric.json'],
      ];
      for (const [name, url] of eggs) {
        const dest = path.join(EGGS_DIR, `egg-${name.toLowerCase()}.json`);
        if (fs.existsSync(dest)) { send(`[SKIP] ${name} (exists)\n`); continue; }
        try {
          await downloadFile(url, dest);
          send(`[OK] ${name}\n`);
        } catch { send(`[WARN] ${name} failed\n`); }
      }

      send('\n=== INSTALLATION COMPLETE ===\n\n');
      return { success: true, panelUrl };
    } catch (err) {
      send(`\n[FATAL] ${err.message}\n`);
      return { success: false, error: err.message };
    }
  });

  ipcMain.handle('wings:install', async (event) => {
    const send = (d) => event.sender.send('cmd:output', d);
    try {
      send('=== WINGS DAEMON INSTALLATION ===\n\n');

      try { await execPromise('wsl --status'); } catch {
        send('[FAIL] WSL not installed. Run: wsl --install\n');
        return { success: false, error: 'WSL not installed' };
      }
      send('[OK] WSL is available\n');

      try { await execPromise('wsl --set-default-version 2'); } catch {}

      let distro = '';
      try {
        const list = await execPromise('wsl --list --quiet');
        const match = list.split('\n').find(l => l.toLowerCase().includes('ubuntu'));
        if (match) distro = match.trim();
      } catch {}

      if (!distro) {
        send('[INFO] Installing Ubuntu-22.04...\n');
        send('[INFO] Complete the Ubuntu setup window, then return here.\n');
        try { await execPromise('start /wait wsl --install -d Ubuntu-22.04'); } catch {}
        try {
          const list = await execPromise('wsl --list --quiet');
          const match = list.split('\n').find(l => l.toLowerCase().includes('ubuntu'));
          if (match) distro = match.trim();
        } catch {}
        if (!distro) {
          send('[FAIL] Ubuntu installation failed or not completed.\n');
          return { success: false, error: 'Ubuntu install failed' };
        }
        send('[OK] Ubuntu installed\n');
      } else {
        send(`[OK] WSL distro: ${distro}\n`);
      }

      try { await execPromise(`wsl --set-version "${distro}" 2`); } catch {}

      send('\n[2] Installing Docker Engine in WSL...\n');
      try {
        await execPromise(`wsl -d "${distro}" -- which docker`);
        send('[OK] Docker already installed in WSL\n');
      } catch {
        send('[INFO] Installing Docker Engine...\n');
        try {
          await execPromise(
            `wsl -d "${distro}" -- bash -c "curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh && sudo usermod -aG docker \\$USER && rm get-docker.sh"`
          );
          send('[OK] Docker Engine installed\n');
        } catch (e) {
          send(`[FAIL] Docker Engine installation failed: ${e.message}\n`);
          return { success: false, error: 'Docker Engine install failed' };
        }
      }

      send('\n[3] Downloading Wings binary...\n');
      try {
        await execPromise(`wsl -d "${distro}" -- which wings`);
        send('[INFO] Wings found, updating...\n');
        await execPromise(
          `wsl -d "${distro}" -- bash -c "curl -L -o /usr/local/bin/wings.new https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64 && chmod +x /usr/local/bin/wings.new && mv /usr/local/bin/wings.new /usr/local/bin/wings"`
        );
        send('[OK] Wings updated\n');
      } catch {
        send('[INFO] Downloading latest Wings release...\n');
        try {
          await execPromise(
            `wsl -d "${distro}" -- bash -c "mkdir -p /etc/pterodactyl && curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64 && chmod +x /usr/local/bin/wings"`
          );
          send('[OK] Wings binary installed\n');
        } catch (e) {
          send(`[FAIL] Wings download failed: ${e.message}\n`);
          return { success: false, error: 'Wings download failed' };
        }
      }

      send('\n[4] Configuring Wings systemd service...\n');
      try {
        const serviceUnit = `[Unit]\nDescription=Pterodactyl Wings Daemon\nAfter=docker.service\nRequires=docker.service\n\n[Service]\nUser=root\nWorkingDirectory=/etc/pterodactyl\nExecStart=/usr/local/bin/wings\nRestart=always\nRestartSec=5\n\n[Install]\nWantedBy=multi-user.target`;
        const escaped = serviceUnit.replace(/'/g, "'\\''");
        await execPromise(
          `wsl -d "${distro}" -- bash -c "cat > /tmp/wings.service << 'SERVICEEOF'\n${serviceUnit}\nSERVICEEOF\nsudo mv /tmp/wings.service /etc/systemd/system/wings.service\nsudo systemctl daemon-reload\nsudo systemctl enable wings"`
        );
        send('[OK] Wings service configured\n');
      } catch (e) {
        send(`[WARN] Service configuration had issues: ${e.message}\n`);
      }

      send('\n[5] Setting up Wings configuration...\n');
      const wingsDir = path.join(DATA_DIR, 'wings');
      if (!fs.existsSync(wingsDir)) fs.mkdirSync(wingsDir, { recursive: true });
      const configPath = path.join(wingsDir, 'config.yml');
      if (!fs.existsSync(configPath)) {
        const template = `# Pterodactyl Wings Configuration\n# Replace with config from Admin > Nodes > Configuration\n\ndebug: false\nuuid: CHANGE-ME\ntoken_id: CHANGE-ME\ntoken: CHANGE-ME\napi:\n  host: 127.0.0.1\n  port: 8080\n  ssl:\n    enabled: false\nsystem:\n  data: /etc/pterodactyl\n  sftp:\n    bind_port: 2022\nremote: http://localhost\n`;
        fs.writeFileSync(configPath, template, 'utf8');
        send('[INFO] Template created at data/wings/config.yml\n');
      } else {
        send('[OK] Existing config.yml found\n');
      }

      send('\n[6] Copying config to WSL and starting Docker...\n');
      try {
        await execPromise(`wsl -d "${distro}" -- bash -c "mkdir -p /etc/pterodactyl && rm -f /etc/pterodactyl/config.yml"`);
        const wslPath = `\\\\wsl.localhost\\${distro}\\etc\\pterodactyl\\config.yml`;
        try {
          fs.copyFileSync(configPath, wslPath);
          send('[OK] Config copied to WSL\n');
        } catch {
          send('[WARN] Direct copy failed. Copy config.yml manually to WSL.\n');
        }
      } catch {}

      try { await execPromise(`wsl -d "${distro}" -- sudo service docker start`); send('[OK] Docker started in WSL\n'); } catch {}

      send('\n=== WINGS INSTALLATION COMPLETE ===\n\n');
      send('Manual steps required:\n');
      send('1. Open the panel in your browser\n');
      send('2. Go to Admin > Nodes > Create New\n');
      send('3. Name: local, FQDN: 127.0.0.1\n');
      send('4. After creation, open the Configuration tab\n');
      send('5. Copy the YAML config\n');
      send('6. Paste it into: data\\wings\\config.yml\n');
      send('7. Run: wsl -d "${distro}" -- sudo systemctl start wings\n\n');

      return { success: true, distro };
    } catch (err) {
      send(`\n[FATAL] ${err.message}\n`);
      return { success: false, error: err.message };
    }
  });

  ipcMain.handle('update:all', async (event) => {
    const send = (d) => event.sender.send('cmd:output', d);
    try {
      send('=== PTEROWINDOWS AUTO-UPDATER ===\n\n');

      try { await execPromise('docker info'); send('[OK] Docker is running\n'); }
      catch { send('[FAIL] Docker not running.\n'); return { success: false, error: 'Docker not running' }; }

      let composeCmd = await findComposeCmd();
      if (!composeCmd) { send('[FAIL] Docker Compose not found.\n'); return { success: false, error: 'No compose' }; }

      send('\n[1/3] Updating Panel...\n');
      try {
        await execPromise(`"${composeCmd}" pull panel`);
        send('[OK] Image pulled\n');
      } catch { send('[WARN] Pull failed\n'); }

      try {
        await execPromise(`"${composeCmd}" up -d --force-recreate panel`);
        send('[OK] Container recreated\n');
      } catch { send('[WARN] Recreate had issues\n'); }

      try {
        await execPromise(`"${composeCmd}" exec -T panel php artisan migrate --seed --force`);
        send('[OK] Migrations ran\n');
      } catch { send('[OK] No new migrations\n'); }

      try { await execPromise(`"${composeCmd}" exec -T panel php artisan view:clear`); } catch {}
      try { await execPromise(`"${composeCmd}" exec -T panel php artisan config:clear`); } catch {}
      send('[OK] Panel updated\n');

      send('\n[2/3] Updating Wings daemon...\n');
      try {
        await execPromise('where wsl');
        const list = await execPromise('wsl --list --quiet');
        const distro = list.split('\n').find(l => l.toLowerCase().includes('ubuntu'));
        if (distro) {
          const d = distro.trim();
          try {
            await execPromise(`wsl -d "${d}" -- bash -c "curl -L -o /usr/local/bin/wings.new https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64 && chmod +x /usr/local/bin/wings.new && mv /usr/local/bin/wings.new /usr/local/bin/wings"`);
            send('[OK] Wings binary updated\n');
            try { await execPromise(`wsl -d "${d}" -- sudo systemctl restart wings`); send('[OK] Wings restarted\n'); } catch {}
          } catch { send('[WARN] Wings update failed\n'); }
        } else { send('[SKIP] No Ubuntu WSL distro\n'); }
      } catch { send('[SKIP] WSL not available\n'); }

      send('\n[3/3] Refreshing eggs...\n');
      if (!fs.existsSync(EGGS_DIR)) fs.mkdirSync(EGGS_DIR);
      const eggs = [
        ['Paper', 'https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/paper/egg-paper.json'],
        ['Spigot', 'https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/spigot/egg-spigot.json'],
        ['Fabric', 'https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/fabric/egg-fabric.json'],
      ];
      for (const [name, url] of eggs) {
        const dest = path.join(EGGS_DIR, `egg-${name.toLowerCase()}.json`);
        try {
          await downloadFile(url, dest);
          send(`[OK] ${name}\n`);
        } catch { send(`[WARN] ${name} failed\n`); }
      }

      send('\n=== UPDATE COMPLETE ===\n\n');
      return { success: true };
    } catch (err) {
      send(`\n[FATAL] ${err.message}\n`);
      return { success: false, error: err.message };
    }
  });

  ipcMain.handle('domain:configure', async (event, domain, email) => {
    const send = (d) => event.sender.send('cmd:output', d);
    try {
      send('=== CUSTOM DOMAIN CONFIGURATION ===\n\n');

      if (!domain) { send('[WARN] No domain provided.\n'); return { success: false }; }

      let url = domain;
      if (!url.startsWith('http://') && !url.startsWith('https://')) url = `https://${url}`;
      writeEnvVar('APP_URL', url);
      send(`[OK] APP_URL set to ${url}\n`);

      if (email) {
        writeEnvVar('LE_EMAIL', email);
        send(`[OK] LE_EMAIL set to ${email}\n`);
      }

      send('[INFO] Restarting panel with new domain...\n');
      try {
        await execPromise('docker info');
        let composeCmd = await findComposeCmd();
        if (composeCmd) {
          try { await execPromise(`"${composeCmd}" up -d --force-recreate panel`); send('[OK] Panel restarted with new domain\n'); }
          catch { send('[WARN] Panel restart failed\n'); }
        }
      } catch {
        send('[WARN] Docker not running. Domain saved but panel not restarted.\n');
      }

      send('\n  Domain:   ' + url + '\n');
      send('  LE_EMAIL: ' + (email || '(not set)') + '\n');
      send('\nEnsure your DNS points to this Windows machine.\n');
      send('Allow ports 80 and 443 through Windows Firewall.\n\n');

      return { success: true, url };
    } catch (err) {
      send(`\n[FATAL] ${err.message}\n`);
      return { success: false, error: err.message };
    }
  });

  ipcMain.handle('eggs:download', async (event) => {
    const send = (d) => event.sender.send('cmd:output', d);
    try {
      send('=== EGG IMPORTER ===\n\n');
      if (!fs.existsSync(EGGS_DIR)) fs.mkdirSync(EGGS_DIR);

      const eggs = [
        ['Paper', 'Minecraft', 'https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/paper/egg-paper.json'],
        ['Spigot', 'Minecraft', 'https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/spigot/egg-spigot.json'],
        ['Fabric', 'Minecraft', 'https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/fabric/egg-fabric.json'],
        ['Forge', 'Minecraft', 'https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/forge/egg-forge.json'],
        ['CurseForge', 'Minecraft', 'https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/curseforge/egg-curseforge-generic.json'],
        ['BungeeCord', 'Minecraft', 'https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/bungeecord/egg-bungeecord.json'],
        ['Purpur', 'Minecraft', 'https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/purpur/egg-purpur.json'],
        ['Folia', 'Minecraft', 'https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/folia/egg-folia.json'],
        ['NeoForge', 'Minecraft', 'https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/neoforge/egg-neoforge.json'],
        ['Magma', 'Minecraft', 'https://raw.githubusercontent.com/pterodactyl/game-eggs/main/minecraft/java/magma/egg-magma.json'],
        ['Gitea', 'Software', 'https://raw.githubusercontent.com/pterodactyl/application-eggs/main/gitea/egg-gitea.json'],
        ['UptimeKuma', 'Software', 'https://raw.githubusercontent.com/pterodactyl/application-eggs/main/uptime-kuma/egg-uptime-kuma.json'],
        ['Grafana', 'Software', 'https://raw.githubusercontent.com/pterodactyl/application-eggs/main/grafana/egg-grafana.json'],
        ['CodeServer', 'Software', 'https://raw.githubusercontent.com/pterodactyl/application-eggs/main/code-server/egg-code-server.json'],
        ['Lavalink', 'Software', 'https://raw.githubusercontent.com/pterodactyl/application-eggs/main/lavalink/egg-lavalink.json'],
        ['Meilisearch', 'Software', 'https://raw.githubusercontent.com/pterodactyl/application-eggs/main/meilisearch/egg-meilisearch.json'],
        ['Minio', 'Storage', 'https://raw.githubusercontent.com/pterodactyl/application-eggs/main/minio/egg-minio.json'],
        ['Elasticsearch', 'Software', 'https://raw.githubusercontent.com/pterodactyl/application-eggs/main/elasticsearch/egg-elasticsearch.json'],
      ];

      let downloaded = 0, skipped = 0;
      for (const [name, , url] of eggs) {
        const dest = path.join(EGGS_DIR, `${name}.json`);
        if (fs.existsSync(dest)) { send(`[SKIP] ${name} (exists)\n`); skipped++; continue; }
        try {
          await downloadFile(url, dest);
          send(`[OK] ${name}\n`);
          downloaded++;
        } catch { send(`[ERR] ${name} failed\n`); }
      }

      send(`\n  Downloaded: ${downloaded}  |  Skipped: ${skipped}\n`);
      send(`  Eggs saved to: ${EGGS_DIR}\n\n`);
      return { success: true, downloaded, skipped };
    } catch (err) {
      send(`\n[FATAL] ${err.message}\n`);
      return { success: false, error: err.message };
    }
  });

  ipcMain.handle('status:get', async (event) => {
    const send = (d) => event.sender.send('cmd:output', d);
    try {
      send('=== PANEL STATUS ===\n\n');

      try {
        await execPromise('docker info');
        send('[OK] Docker: running\n');
      } catch {
        send('[FAIL] Docker: not running\n');
        return { docker: false };
      }

      let composeCmd = await findComposeCmd();

      send('\nContainer status:\n');
      if (composeCmd) {
        try {
          const ps = await execPromise(`"${composeCmd}" ps`);
          send(ps + '\n');
        } catch { send('(could not get container status)\n'); }
      }

      send('\nPanel health check:\n');
      try {
        await execPromise('curl -s http://localhost/api/health');
        send('  [OK] Panel is responding\n');
      } catch {
        send('  [WARN] Panel not responding\n');
      }

      send('\nCurrent configuration:\n');
      const env = readEnvFile();
      for (const key of ['APP_URL', 'APP_TIMEZONE', 'APP_ENV', 'HTTP_PORT', 'HTTPS_PORT', 'LE_EMAIL']) {
        if (env[key]) send(`  ${key}=${env[key]}\n`);
      }

      send('\nData directory size:\n');
      if (fs.existsSync(DATA_DIR)) {
        try {
          const size = await execPromise(
            `powershell -command "$p=Get-ChildItem '${DATA_DIR.replace(/'/g, "''")}' -Recurse -ErrorAction SilentlyContinue; $s=($p | Measure-Object Length -Sum).Sum; if($s -gt 1GB){'{0:N2} GB' -f ($s/1GB)}elseif($s -gt 1MB){'{0:N2} MB' -f ($s/1MB)}else{'< 1 MB'}"`
          );
          send(`  ${size}\n`);
        } catch { send('  (unknown)\n'); }
      } else {
        send('  No data directory\n');
      }

      send('\n');
      return { docker: true, env };
    } catch (err) {
      send(`\n[FATAL] ${err.message}\n`);
      return { docker: false, error: err.message };
    }
  });

  ipcMain.handle('services:restart', async (event) => {
    const send = (d) => event.sender.send('cmd:output', d);
    try {
      send('Restarting all services...\n\n');
      let composeCmd = await findComposeCmd();
      if (composeCmd) {
        try {
          await execPromise(`"${composeCmd}" restart`);
          send('[OK] All services restarted\n');
        } catch { send('[FAIL] Failed to restart services\n'); }
      }

      try {
        await execPromise('where wsl');
        const list = await execPromise('wsl --list --quiet');
        const distro = list.split('\n').find(l => l.toLowerCase().includes('ubuntu'));
        if (distro) {
          try {
            await execPromise(`wsl -d "${distro.trim()}" -- sudo systemctl restart wings`);
            send(`[OK] Wings restarted in ${distro.trim()}\n`);
          } catch {}
        }
      } catch {}

      send('\n');
      return { success: true };
    } catch (err) {
      send(`\n[FATAL] ${err.message}\n`);
      return { success: false, error: err.message };
    }
  });

  ipcMain.handle('services:stop', async (event) => {
    const send = (d) => event.sender.send('cmd:output', d);
    try {
      send('Stopping all services...\n\n');
      let composeCmd = await findComposeCmd();
      if (composeCmd) {
        try {
          await execPromise(`"${composeCmd}" down`);
          send('[OK] All services stopped\n');
        } catch { send('[FAIL] Failed to stop services\n'); }
      }
      send('\n');
      return { success: true };
    } catch (err) {
      send(`\n[FATAL] ${err.message}\n`);
      return { success: false, error: err.message };
    }
  });

  ipcMain.handle('logs:get', async (event, source) => {
    const send = (d) => event.sender.send('cmd:output', d);
    try {
      let composeCmd = await findComposeCmd();
      if (!composeCmd) { send('[FAIL] Docker Compose not available.\n'); return { success: false }; }

      send(`=== Logs: ${source} ===\n\n`);

      if (source === 'panel' || source === 'database') {
        try {
          const logs = await execPromise(`"${composeCmd}" logs --tail=200 ${source}`);
          send(logs + '\n');
        } catch { send('(no logs available)\n'); }
      } else if (source === 'nginx') {
        const logDir = path.join(DATA_DIR, 'panel', 'logs');
        if (fs.existsSync(logDir)) {
          try {
            const files = fs.readdirSync(logDir).filter(f => f.endsWith('.log'));
            if (files.length > 0) {
              send(`Log files in ${logDir}:\n`);
              files.forEach(f => send(`  ${f}\n`));
            } else {
              send('No local log files found.\n');
              try {
                const logs = await execPromise(`"${composeCmd}" exec -T panel ls -la /app/storage/logs/`);
                send(logs + '\n');
              } catch {}
            }
          } catch { send('(error reading logs)\n'); }
        } else {
          send('Log directory not found.\n');
        }
      }

      send('\n');
      return { success: true };
    } catch (err) {
      send(`\n[FATAL] ${err.message}\n`);
      return { success: false, error: err.message };
    }
  });

  ipcMain.handle('file:check', async (_, filePath) => {
    try {
      const fullPath = path.join(APP_DIR, filePath);
      return { exists: fs.existsSync(fullPath) };
    } catch { return { exists: false }; }
  });

  ipcMain.handle('dns:resolve', async (_, domain) => {
    try {
      const cleanDomain = domain.replace(/^https?:\/\//, '').replace(/\/.*$/, '').split(':')[0];
      const addresses = await new Promise((resolve, reject) => {
        dns.resolve4(cleanDomain, (err, addresses) => {
          if (err) reject(err); else resolve(addresses);
        });
      });
      const localIPs = [];
      const ifaces = os.networkInterfaces();
      for (const name of Object.keys(ifaces)) {
        for (const iface of ifaces[name]) {
          if (iface.family === 'IPv4' && !iface.internal) localIPs.push(iface.address);
        }
      }
      const matchesLocal = addresses.some(addr => localIPs.includes(addr));
      return { success: true, domain: cleanDomain, addresses, localIPs, matchesLocal };
    } catch (err) {
      return { success: false, error: err.message };
    }
  });

  ipcMain.handle('network:external-ip', async () => {
    try {
      const ip = await new Promise((resolve, reject) => {
        https.get('https://api.ipify.org?format=json', { timeout: 10000 }, (res) => {
          let data = '';
          res.on('data', chunk => data += chunk);
          res.on('end', () => { try { resolve(JSON.parse(data).ip); } catch { reject(new Error('Parse failed')); } });
        }).on('error', reject);
      });
      return { success: true, ip };
    } catch { return { success: false, error: 'Could not determine external IP' }; }
  });

  ipcMain.handle('port:check', async (_, host, port) => {
    try {
      const isOpen = await new Promise((resolve) => {
        const socket = new net.Socket();
        socket.setTimeout(5000);
        socket.on('connect', () => { socket.destroy(); resolve(true); });
        socket.on('error', () => resolve(false));
        socket.on('timeout', () => { socket.destroy(); resolve(false); });
        socket.connect(port, host);
      });
      return { success: true, host, port, open: isOpen };
    } catch { return { success: false, error: 'Check failed' }; }
  });

  ipcMain.handle('firewall:check', async (_, port) => {
    try {
      const rules = await execPromise(`netsh advfirewall firewall show rule name=all dir=in verbose | findstr /i "${port}"`);
      const hasRule = rules.length > 0;
      return { success: true, port, hasRule };
    } catch { return { success: true, port, hasRule: false }; }
  });

  ipcMain.handle('ssl:check', async (_, domain) => {
    try {
      const cleanDomain = domain.replace(/^https?:\/\//, '').replace(/\/.*$/, '').split(':')[0];
      const certInfo = await new Promise((resolve, reject) => {
        const req = https.get(`https://${cleanDomain}`, { timeout: 15000, rejectUnauthorized: false }, (res) => {
          const cert = res.socket.getPeerCertificate();
          if (!cert || Object.keys(cert).length === 0) {
            resolve({ valid: false, reason: 'No certificate presented' });
            return;
          }
          const now = new Date();
          const valid = new Date(cert.valid_to) > now && new Date(cert.valid_from) < now;
          resolve({
            valid,
            subject: cert.subject ? cert.subject.CN : '',
            issuer: cert.issuer ? cert.issuer.O : '',
            validFrom: cert.valid_from,
            validTo: cert.valid_to,
            daysRemaining: Math.floor((new Date(cert.valid_to) - now) / (1000 * 60 * 60 * 24)),
          });
          res.resume();
        });
        req.on('error', (err) => resolve({ valid: false, reason: err.message }));
        req.end();
      });
      return { success: true, ...certInfo };
    } catch (err) {
      return { success: false, error: err.message };
    }
  });

}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 860,
    minWidth: 960,
    minHeight: 640,
    title: 'PteroWindows - Pterodactyl Panel Manager',
    icon: path.join(APP_DIR, 'icon.png'),
    backgroundColor: '#07070d',
    webPreferences: {
      preload: path.join(APP_DIR, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
    },
    show: false,
  });

  mainWindow.loadFile(path.join(APP_DIR, 'renderer', 'index.html'));

  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
    mainWindow.focus();
  });

  mainWindow.on('closed', () => { mainWindow = null; });
}

app.whenReady().then(() => {
  setupIPC();
  createWindow();
  app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
});

app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });
