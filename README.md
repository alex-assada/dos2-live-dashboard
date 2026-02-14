# DOS2 Live Dashboard Prototype

This repository includes:

- `mod/BootstrapServer.lua`: Script Extender Lua exporter for live party data.
- `server/server.js`: Node.js Express backend (`POST /update`, `GET /status`).
- `ui/index.html`: Basic live dashboard UI polling `/status`.

## 1) Run the backend

```bash
cd server
npm install
npm start
```

Backend starts on `http://localhost:3000`.

## 2) Serve the UI

Any static file server works, for example:

```bash
cd ui
python3 -m http.server 8080
```

Then open `http://localhost:8080`.

## 3) Install the Lua mod script

Copy `mod/BootstrapServer.lua` into your DOS2 mod Lua bootstrap location:

`Mods/<YourModUUID>/Story/RawFiles/Lua/BootstrapServer.lua`

The script emits snapshots every ~1.5 seconds to:

`http://localhost:3000/update`

## Notes on DOS2 API differences

Script Extender API surface can vary by build and project setup.  
`mod/BootstrapServer.lua` uses guarded calls and fallbacks:

- Preferred HTTP transport: `Ext.Net.HttpRequest` (if available in your build)
- Fallback: writes payload to `DOS2Dashboard/latest_snapshot.json`

If your build exposes alternate functions for party, inventory, or statuses, adjust the helper functions in `BootstrapServer.lua` accordingly.
