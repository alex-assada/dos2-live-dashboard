# DOS2 Live Dashboard Handoff

## Repository Contents
- `mod/BootstrapServer.lua`
  - DOS2 Script Extender Lua exporter.
  - Collects party/player data, equipment, inventory, vitals, statuses.
  - Attempts HTTP POST to `http://localhost:3000/update`.
  - In your environment, HTTP is unavailable from SE, so it writes fallback JSON snapshot file.
- `server/server.js`
  - Express API with:
    - `POST /update` (direct push path)
    - `GET /status`
    - `GET /health`
  - Added snapshot-file bridge polling:
    - Reads DOS2 fallback file each second and updates in-memory state.
- `ui/index.html`
  - Polls `http://localhost:3000/status`.
  - Shows cards + expandable equipment/inventory.
- `README.md`
  - Basic run instructions.

## Critical Environment Details (This Machine)
- Game install:
  - `/home/alex/.local/share/Steam/steamapps/common/Divinity Original Sin 2`
- Active DOS2 profile path (Proton):
  - `/home/alex/.local/share/Steam/steamapps/compatdata/435150/pfx/drive_c/users/steamuser/Documents/Larian Studios/Divinity Original Sin 2 Definitive Edition`
- Active mods folder:
  - `.../Mods`
- Active profile modsettings:
  - `.../PlayerProfiles/Don Peps/modsettings.lsx`
- Extender logs:
  - `.../Extender Logs/Extender Runtime *.log`
- Fallback snapshot file written by Lua mod:
  - `.../Osiris Data/DOS2Dashboard/latest_snapshot.json`

## Current Working Design
1. DOS2 Lua mod loads via Script Extender.
2. Lua writes snapshot file repeatedly (fallback path) because outbound HTTP is unavailable in this SE runtime.
3. Node server polls snapshot file and maps it into `/status`.
4. UI polls `/status`.

## Verified Facts from Latest Logs
- Dashboard bootstrap scripts load successfully:
  - `Loading bootstrap script: Mods/DOS2Dashboard.../BootstrapClient.lua`
  - `Loading bootstrap script: Mods/DOS2Dashboard.../BootstrapServer.lua`
- Lua mod logs:
  - `[DOS2 Dashboard] Registered ticker with Ext.Events.Tick`
  - `[DOS2 Dashboard] Live dashboard exporter initialized. Target: http://localhost:3000/update`
  - Repeated fallback notice:
  - `[DOS2 Dashboard] HTTP API unavailable; wrote fallback snapshot to DOS2Dashboard/latest_snapshot.json`

## Major Issues Encountered and Resolved
- Mod not appearing / incompatible:
  - Root cause: invalid `meta.lsx` structure/types and wrong package internal path.
  - Fix: package contains `Mods/<Folder>/...`, and metadata aligned to DE-compatible format.
- Mod repeatedly removed from `modsettings.lsx`:
  - Root cause: compatibility mismatch; DOS2 rewrote file.
  - Fix: corrected metadata version/schema so DOS2 retains module.
- UI showing `Waiting for backend...`:
  - Root cause: Node backend process was down, while UI server still ran.
  - Fix: restart backend.
- Massive non-party entity dump:
  - Root cause: overly broad fallback player detection.
  - Fix: `getPlayers()` now prefers `DB_PartyMembers`, then `DB_IsPlayer`, strict `IsPlayer` fallback.

## Runtime Process Notes
- UI port `8080` often already in use from existing process.
- Backend port `3000` may die if process not kept running in active terminal/session.

## Known Good Commands
- Backend:
  - `cd /home/alex/repos/dos2-planner/server && node server.js`
- UI:
  - `cd /home/alex/repos/dos2-planner/ui && python3 -m http.server 8080`
- Validate:
  - `curl http://localhost:3000/health`
  - `curl http://localhost:3000/status`

## If UI Shows Nothing
1. Confirm backend is running:
   - `ps -ef | rg "node server.js"`
2. Confirm snapshot file updates:
   - `ls -la ".../Osiris Data/DOS2Dashboard/latest_snapshot.json"`
3. Confirm mod loaded in latest extender log:
   - search for `DOS2 Dashboard` and `BootstrapServer.lua`.
4. Confirm active profile modsettings still contains dashboard UUID:
   - `7e6b5d92-3991-4210-beb1-64fd3f6482f8`

## Current UUID / Names
- Mod UUID:
  - `7e6b5d92-3991-4210-beb1-64fd3f6482f8`
- Mod folder/package base name:
  - `DOS2Dashboard_7e6b5d92-3991-4210-beb1-64fd3f6482f8`
- Display name:
  - `DOS2 Live Dashboard`

## Git Status Note
- This directory was not originally a git repo; it must be initialized before first push.
