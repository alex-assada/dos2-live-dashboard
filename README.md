# DOS2 Live Dashboard Prototype

This repository includes:

- `mod/BootstrapServer.lua`: Script Extender Lua exporter for live party data.
- `server/server.js`: Node.js Express backend (`POST /update`, `GET /status`).
- `ui/index.html`: Basic live dashboard UI polling `/status`.

## Important runtime note

On this machine's current Script Extender runtime, outbound HTTP from Lua is unavailable.  
So the active working path is:

1. Lua writes fallback snapshots to:
   `.../Divinity Original Sin 2 Definitive Edition/Osiris Data/DOS2Dashboard/latest_snapshot.json`
2. `server/server.js` polls that file and serves the latest state at `/status`.

Direct `POST /update` still exists and works if your SE build supports `Ext.Net.HttpRequest`.

## 1) Run the backend

```bash
cd server
npm install
npm start
```

Backend starts on `http://localhost:3000`.

Useful endpoint checks:

- `http://localhost:3000/health`
- `http://localhost:3000/status`

Optional env vars:

- `DOS2_SNAPSHOT_PATH` (override snapshot file path)
- `DOS2_SNAPSHOT_POLL_MS` (poll interval, default `1000`)

## 2) Serve the UI

Any static file server works:

```bash
cd ui
python3 -m http.server 8080
```

Then open `http://localhost:8080`.

If port `8080` is already in use, either:

- reuse the existing UI server, or
- stop it (`pkill -f "python3 -m http.server 8080"`) and restart.

## 3) Install the Lua mod script

Copy `mod/BootstrapServer.lua` into your DOS2 mod Lua bootstrap location:

`Mods/<YourModUUID>/Story/RawFiles/Lua/BootstrapServer.lua`

The script ticks every ~1.5s and:

- tries `http://localhost:3000/update` via `Ext.Net.HttpRequest` (if available),
- otherwise writes fallback JSON snapshot file (working path here).

## Running from another machine / VM

### Same machine as game (recommended)

- Run backend + UI locally.
- Open:
  - `http://localhost:8080`
  - `http://localhost:3000/status`

### Different machine for UI only

- Keep game + backend on game machine.
- Open UI from remote machine:
  - `http://<GAME_MACHINE_IP>:8080`

### Different machine for backend/UI

- If your SE build supports HTTP:
  - set Lua target URL to VM IP in `BootstrapServer.lua`
  - example: `http://192.168.x.x:3000/update`
- If your SE build does not support HTTP (this environment):
  - share the snapshot file into VM (SMB/shared folder),
  - run backend in VM with:
    - `DOS2_SNAPSHOT_PATH=<shared_path>/latest_snapshot.json node server.js`

## Notes on DOS2 API differences

Script Extender API surface varies by build/mod setup.  
`mod/BootstrapServer.lua` uses guarded calls and fallbacks, but you may still need to adjust helper fields/functions for your SE version.
