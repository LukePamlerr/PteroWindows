const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  onOutput: (callback) => {
    ipcRenderer.on('cmd:output', (_event, data) => callback(data));
  },
  removeOutputListener: () => {
    ipcRenderer.removeAllListeners('cmd:output');
  },

  checkDocker: () => ipcRenderer.invoke('docker:check'),
  readEnv: () => ipcRenderer.invoke('env:read'),
  saveEnv: (key, value) => ipcRenderer.invoke('env:save', key, value),
  generatePassword: () => ipcRenderer.invoke('password:generate'),

  installPanel: (config) => ipcRenderer.invoke('panel:install', config),
  installWings: () => ipcRenderer.invoke('wings:install'),
  updateAll: () => ipcRenderer.invoke('update:all'),
  configureDomain: (domain, email) => ipcRenderer.invoke('domain:configure', domain, email),
  downloadEggs: () => ipcRenderer.invoke('eggs:download'),

  getStatus: () => ipcRenderer.invoke('status:get'),
  restartServices: () => ipcRenderer.invoke('services:restart'),
  stopServices: () => ipcRenderer.invoke('services:stop'),
  getLogs: (source) => ipcRenderer.invoke('logs:get', source),

  checkFile: (filePath) => ipcRenderer.invoke('file:check', filePath),

  resolveDns: (domain) => ipcRenderer.invoke('dns:resolve', domain),
  getExternalIp: () => ipcRenderer.invoke('network:external-ip'),
  checkPort: (host, port) => ipcRenderer.invoke('port:check', host, port),
  checkFirewall: (port) => ipcRenderer.invoke('firewall:check', port),
  checkSsl: (domain) => ipcRenderer.invoke('ssl:check', domain),
});
