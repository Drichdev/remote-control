## PC Remote Control (Flutter + Electron)

### 📖 Overview

This project lets you control your PC from a Flutter app (mobile, web, or desktop) over Wi-Fi—no cables needed. The workflow is:

1. **Discovery**: Flutter broadcasts a UDP “discover” packet on the LAN.  
2. **Response**: Electron hears the broadcast and replies with its IP & port.  
3. **WebSocket**: Flutter connects via WebSocket to the Electron server.  
4. **Selection**: In the Electron UI, you click “Connect” on your phone’s name.  
5. **Control**: Flutter sends commands (`left`, `right`, `up`, `down`, `esc`) over WS. Electron simulates those key presses via **robotjs** and logs them.

### Preview

![Project Preview](demo.gif)

### 🌐 IP & Discovery Method

1. **Localhost attempt**  
   - Flutter first tries `ws://localhost:8080` (iOS/macOS/Windows) or `ws://10.0.2.2:8080` (Android emulator).  
2. **UDP fallback**  
   - If that fails, Flutter broadcasts every 500 ms to `255.255.255.255:41234`:
     ```json
     { "type": "discover", "name": "<deviceName>", "token": "<sharedToken>" }
     ```
   - Electron replies to the sender:
     ```json
     { "type": "server-info", "ip": "<serverIP>", "port": 8080, "token": "<sharedToken>" }
     ```
   - Flutter stops broadcasting and reconnects via WS to the provided IP.  
3. **Handshake**  
   - Flutter sends `{ type: "discover", name, token }` on WS; Electron responds `{ type: "discover_ok" }`.  
   - After you click **Connect**, Electron sends `{ type: "select_ok" }` to Flutter, enabling command buttons.  

---

### 🛠 Tech Stack

- **Flutter** (Dart)  
  - `web_socket_channel` for WebSocket  
  - `dart:io` for UDP socket (mobile/desktop)  
- **Electron** (Node.js)  
  - `ws` for WebSocket server  
  - `dgram` for UDP discovery  
  - `robotjs` for simulating keyboard events  
- **HTML/CSS/JS** for the Electron UI  

---

### 🚀 Installation

### Prerequisites

- **Node.js** ≥14 & **npm**  
- **Flutter SDK**  
- Android SDK or Xcode if targeting mobile  

### Setup Electron (server)

```bash
cd electron-app
npm install
npm run start
```

### Setup Flutter 

```bash
cd flutter-app
flutter pub get
flutter run
```