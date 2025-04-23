const dgram     = require('dgram');
const os        = require('os');
const path      = require('path');
const { app, BrowserWindow, ipcMain } = require('electron');
const WebSocket = require('ws');
const robot     = require('robotjs');

const WS_PORT      = 8080;
const UDP_PORT     = 41234;
const SHARED_TOKEN = 'mon_secret_partagé';

let mainWindow;
let devices        = [];
let wsClients      = {};
let selectedDevice = null;

function getLocalIp() {
  const ifs = os.networkInterfaces();
  for (let name in ifs) {
    for (let i of ifs[name]) {
      if (i.family === 'IPv4' && !i.internal) return i.address;
    }
  }
  return '127.0.0.1';
}

function norm(addr) {
  if (addr === '::1') return '127.0.0.1';
  const m = addr.match(/^::ffff:(\d+\.\d+\.\d+\.\d+)$/);
  if (m) return m[1];
  return addr;
}

function addOrUpdate(name, addr) {
  addr = norm(addr);
  const idx = devices.findIndex(d => d.addr === addr);
  if (idx >= 0) devices[idx].name = name;
  else devices.push({ name, addr });
  mainWindow && mainWindow.webContents.send('device-list', devices);
}

// UDP Discovery
const udp = dgram.createSocket('udp4');
udp.on('message', (msg, rinfo) => {
  try {
    const o = JSON.parse(msg.toString());
    if (o.type === 'discover' && o.token === SHARED_TOKEN) {
      udp.send(
        JSON.stringify({ type:'server-info', ip:getLocalIp(), port:WS_PORT, token:SHARED_TOKEN }),
        rinfo.port, rinfo.address
      );
      addOrUpdate(o.name || rinfo.address, rinfo.address);
    }
  } catch (_) {}
});
udp.bind(UDP_PORT, () => {
  udp.setBroadcast(true);
  console.log(`📡 UDP listening on ${UDP_PORT}`);
});

// WebSocket Server
const wss = new WebSocket.Server({ port: WS_PORT }, () =>
  console.log(`🔌 WS listening on ${WS_PORT}`)
);

wss.on('connection', (ws, req) => {
  const addr = norm(req.socket.remoteAddress);
  wsClients[addr] = ws;
  console.log('📱 WS client connected:', addr);
  mainWindow && mainWindow.webContents.send('device-list', devices);

  ws.on('message', msg => {
    const str = msg.toString();
    console.log(`📨 WS message from ${addr}: ${str}`);

    // Discover over WS?
    let obj;
    try { obj = JSON.parse(str); } catch (_) {}

    if (obj?.type === 'discover' && obj.token === SHARED_TOKEN) {
      addOrUpdate(obj.name || addr, addr);
      ws.send(JSON.stringify({ type:'discover_ok' }));
      return;
    }

    // Commandes : si c'est le device sélectionné
    if (addr === selectedDevice) {
      // Simule la touche
      switch (str) {
        case 'left':  robot.keyTap('left');  break;
        case 'right': robot.keyTap('right'); break;
        case 'up':    robot.keyTap('up');    break;
        case 'down':  robot.keyTap('down');  break;
        case 'esc':   robot.keyTap('escape');break;
        default:      console.log('❓ Unknown command:', str);
      }
      // Envoie la commande à l'UI pour affichage
      mainWindow && mainWindow.webContents.send('command', str);
    } else {
      console.log(`⚠️ Ignored command from ${addr} (not selected)`);
    }
  });

  ws.on('close', () => {
    delete wsClients[addr];
    console.log('❌ WS client disconnected:', addr);
  });
});

// IPC depuis l'UI
ipcMain.on('select-device', (_, addr) => {
  selectedDevice = addr;
  console.log('✅ Device selected:', addr);
  mainWindow.webContents.send('selected-device', addr);
  const ws = wsClients[addr];
  if (ws) ws.send(JSON.stringify({ type:'select_ok' }));
});

ipcMain.on('disconnect-device', (_, addr) => {
  if (selectedDevice === addr) {
    const ws = wsClients[addr];
    if (ws) ws.send(JSON.stringify({ type:'disconnect_ok' }));
    selectedDevice = null;
    console.log('❎ Device disconnected:', addr);
    mainWindow.webContents.send('selected-device', null);
  }
});

// Création de la fenêtre Electron
function createWindow() {
  mainWindow = new BrowserWindow({
    width: 800, height: 500,
    webPreferences: { nodeIntegration:true, contextIsolation:false }
  });
  mainWindow.loadFile(path.join(__dirname, 'index.html'));
  mainWindow.webContents.on('did-finish-load', () => {
    mainWindow.webContents.send('device-list', devices);
    if (selectedDevice) mainWindow.webContents.send('selected-device', selectedDevice);
  });
}

app.whenReady().then(createWindow);
app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });
