(function() {
  'use strict';

  const api = window.electronAPI;
  const output = document.getElementById('outputContent');
  const outputPanel = document.getElementById('output-panel');

  let busy = false;

  function log(text, cls) {
    if (output.querySelector('.output-placeholder')) output.innerHTML = '';
    const span = document.createElement('span');
    span.textContent = text;
    if (cls) span.className = 'output-' + cls;
    output.appendChild(span);
    output.scrollTop = output.scrollHeight;
  }

  function clearOutput() {
    output.innerHTML = '<span class="output-placeholder">Ready. Select an action to begin.</span>';
  }

  function setBusy(b) {
    busy = b;
    document.querySelectorAll('.btn:not(.btn-sm)').forEach(el => el.disabled = b);
  }

  api.onOutput(function(data) {
    if (output.querySelector('.output-placeholder')) output.innerHTML = '';
    const lines = data.split('\n');
    for (const line of lines) {
      if (!line) continue;
      let cls = 'info';
      if (line.includes('[OK]')) cls = 'ok';
      else if (line.includes('[WARN]') || line.includes('[SKIP]')) cls = 'warn';
      else if (line.includes('[FAIL]') || line.includes('[ERR]') || line.includes('[FATAL]')) cls = 'err';
      else if (line.includes('===')) cls = 'section';
      const span = document.createElement('span');
      span.textContent = line + '\n';
      span.className = 'output-' + cls;
      output.appendChild(span);
    }
    output.scrollTop = output.scrollHeight;
  });

  // Navigation
  document.querySelectorAll('.nav-item').forEach(function(item) {
    item.addEventListener('click', function() {
      if (busy) return;
      document.querySelectorAll('.nav-item').forEach(function(n) { n.classList.remove('active'); });
      this.classList.add('active');
      document.querySelectorAll('.section').forEach(function(s) { s.classList.remove('active'); });
      var section = document.getElementById('section-' + this.dataset.section);
      if (section) section.classList.add('active');
    });
  });

  // Check Docker on load
  (function init() {
    updateDockerIndicator();
    loadDashboard();
    loadDomainDisplay();
  })();

  function updateDockerIndicator() {
    var dot = document.getElementById('dockerDot');
    var status = document.getElementById('dockerStatus');
    dot.className = 'indicator-dot checking';
    status.textContent = 'Checking...';
    api.checkDocker().then(function(result) {
      if (result.installed && result.running) {
        dot.className = 'indicator-dot online';
        status.textContent = 'Docker: Running';
      } else if (result.installed) {
        dot.className = 'indicator-dot offline';
        status.textContent = 'Docker: Not running';
      } else {
        dot.className = 'indicator-dot offline';
        status.textContent = 'Docker: Not installed';
      }
    }).catch(function() {
      dot.className = 'indicator-dot offline';
      status.textContent = 'Docker: Error';
    });
  }

  // Dashboard
  async function loadDashboard() {
    try {
      var docker = await api.checkDocker();
      document.getElementById('dashDockerValue').textContent = (docker.installed && docker.running) ? 'Running' : docker.installed ? 'Not running' : 'Not installed';
      document.getElementById('dashDockerValue').style.color = (docker.installed && docker.running) ? 'var(--success)' : 'var(--danger)';
    } catch { document.getElementById('dashDockerValue').textContent = 'Error'; }

    try {
      var result = await api.checkFile('data/panel');
      document.getElementById('dashPanelValue').textContent = result.exists ? 'Installed' : 'Not installed';
      document.getElementById('dashPanelValue').style.color = result.exists ? 'var(--success)' : 'var(--text-muted)';
    } catch { document.getElementById('dashPanelValue').textContent = '?'; }

    try {
      var result = await api.checkFile('data/wings/config.yml');
      document.getElementById('dashWingsValue').textContent = result.exists ? 'Configured' : 'Not configured';
      document.getElementById('dashWingsValue').style.color = result.exists ? 'var(--success)' : 'var(--text-muted)';
    } catch { document.getElementById('dashWingsValue').textContent = '?'; }

    try {
      var files = await api.checkFile('eggs/egg-paper.json');
      document.getElementById('dashEggsValue').textContent = files.exists ? 'Downloaded' : 'None';
      document.getElementById('dashEggsValue').style.color = files.exists ? 'var(--success)' : 'var(--text-muted)';
    } catch { document.getElementById('dashEggsValue').textContent = '?'; }

    try {
      var env = await api.readEnv();
      var el = document.getElementById('dashEnv');
      if (Object.keys(env).length === 0) {
        el.textContent = '(no .env file found)';
      } else {
        el.textContent = Object.entries(env).map(function(e) { return e[0] + '=' + e[1]; }).join('\n');
      }
    } catch { document.getElementById('dashEnv').textContent = '(error reading .env)'; }
  }

  // Domain display
  async function loadDomainDisplay() {
    try {
      var env = await api.readEnv();
      document.getElementById('currentAppUrl').textContent = env.APP_URL || '(not set)';
      document.getElementById('currentLeEmail').textContent = env.LE_EMAIL || '(not set)';
    } catch {}
  }

  // Panel install
  document.getElementById('btnInstallPanel').addEventListener('click', async function() {
    if (busy) return;
    clearOutput();
    setBusy(true);

    var config = {};

    var domain = document.getElementById('panelDomain').value.trim();
    if (domain) config.domain = domain;

    var email = document.getElementById('panelEmail').value.trim();
    if (email) config.email = email;

    var adminEmail = document.getElementById('adminEmail').value.trim();
    var adminUser = document.getElementById('adminUser').value.trim();
    if (adminEmail && adminUser) {
      config.adminEmail = adminEmail;
      config.adminUsername = adminUser;
      var adminPass = document.getElementById('adminPass').value.trim();
      if (adminPass) config.adminPassword = adminPass;
    }

    config.generatePasswords = document.getElementById('genDbPass').checked;

    try {
      var result = await api.installPanel(config);
      if (!result.success) {
        log('\nInstallation failed: ' + (result.error || 'unknown error'), 'err');
      }
    } catch (err) {
      log('\n[FATAL] ' + err.message + '\n', 'err');
    }

    setBusy(false);
    updateDockerIndicator();
    loadDashboard();
    loadDomainDisplay();
  });

  // Wings install
  document.getElementById('btnInstallWings').addEventListener('click', async function() {
    if (busy) return;
    clearOutput();
    setBusy(true);
    try {
      await api.installWings();
    } catch (err) {
      log('\n[FATAL] ' + err.message + '\n', 'err');
    }
    setBusy(false);
    loadDashboard();
  });

  // Update all
  document.getElementById('btnUpdateAll').addEventListener('click', async function() {
    if (busy) return;
    clearOutput();
    setBusy(true);
    try {
      await api.updateAll();
    } catch (err) {
      log('\n[FATAL] ' + err.message + '\n', 'err');
    }
    setBusy(false);
    loadDashboard();
  });

  // Domain configure
  document.getElementById('btnConfigureDomain').addEventListener('click', async function() {
    if (busy) return;
    var domain = document.getElementById('domainInput').value.trim();
    if (!domain) {
      log('[WARN] Please enter a domain.\n', 'warn');
      return;
    }
    clearOutput();
    setBusy(true);
    try {
      var email = document.getElementById('domainEmail').value.trim();
      await api.configureDomain(domain, email || null);
    } catch (err) {
      log('\n[FATAL] ' + err.message + '\n', 'err');
    }
    setBusy(false);
    loadDomainDisplay();
    loadDashboard();
  });

  // Download eggs
  document.getElementById('btnDownloadEggs').addEventListener('click', async function() {
    if (busy) return;
    clearOutput();
    setBusy(true);
    try {
      await api.downloadEggs();
    } catch (err) {
      log('\n[FATAL] ' + err.message + '\n', 'err');
    }
    setBusy(false);
    loadDashboard();
  });

  // Status
  document.getElementById('btnGetStatus').addEventListener('click', async function() {
    if (busy) return;
    clearOutput();
    setBusy(true);
    try {
      var result = await api.getStatus();
      var grid = document.getElementById('statusGrid');
      grid.innerHTML = '';

      if (result.docker) {
        addStatusItem(grid, 'Docker', 'Running', 'ok');
      } else {
        addStatusItem(grid, 'Docker', 'Not running', 'err');
      }

      if (result.env) {
        addStatusItem(grid, 'APP_URL', result.env.APP_URL || '(not set)', result.env.APP_URL ? 'ok' : 'warn');
        addStatusItem(grid, 'LE_EMAIL', result.env.LE_EMAIL || '(not set)', 'info');
        addStatusItem(grid, 'APP_TIMEZONE', result.env.APP_TIMEZONE || '(not set)', 'info');
        addStatusItem(grid, 'APP_ENV', result.env.APP_ENV || '(not set)', 'info');

        var envEl = document.getElementById('statusEnv');
        envEl.textContent = Object.keys(result.env).length === 0 ? '(no .env file)' : Object.entries(result.env).map(function(e) { return e[0] + '=' + e[1]; }).join('\n');
      }
    } catch (err) {
      log('\n[FATAL] ' + err.message + '\n', 'err');
    }
    setBusy(false);
  });

  function addStatusItem(grid, title, value, cls) {
    var div = document.createElement('div');
    div.className = 'status-item';
    div.innerHTML = '<div class="status-item-title">' + title + '</div><div class="status-item-value ' + cls + '">' + value + '</div>';
    grid.appendChild(div);
  }

  // Restart
  document.getElementById('btnRestart').addEventListener('click', async function() {
    if (busy) return;
    clearOutput();
    setBusy(true);
    try {
      await api.restartServices();
    } catch (err) {
      log('\n[FATAL] ' + err.message + '\n', 'err');
    }
    setBusy(false);
  });

  // Stop
  document.getElementById('btnStop').addEventListener('click', async function() {
    if (busy) return;
    clearOutput();
    setBusy(true);
    try {
      await api.stopServices();
    } catch (err) {
      log('\n[FATAL] ' + err.message + '\n', 'err');
    }
    setBusy(false);
    updateDockerIndicator();
    loadDashboard();
  });

  // Logs
  document.querySelectorAll('[data-log]').forEach(function(btn) {
    btn.addEventListener('click', async function() {
      if (busy) return;
      var source = this.dataset.log;
      clearOutput();
      setBusy(true);
      try {
        await api.getLogs(source);
      } catch (err) {
        log('\n[FATAL] ' + err.message + '\n', 'err');
      }
      setBusy(false);
    });
  });

  // Clear output
  document.getElementById('btnClearOutput').addEventListener('click', clearOutput);

  // Toggle output panel height
  var outputCollapsed = false;
  document.getElementById('outputToggle').addEventListener('click', function() {
    outputCollapsed = !outputCollapsed;
    outputPanel.style.height = outputCollapsed ? '36px' : '';
    outputPanel.style.flex = outputCollapsed ? '0 0 auto' : '';
  });

  // Refresh docker indicator periodically
  setInterval(updateDockerIndicator, 15000);

})();
