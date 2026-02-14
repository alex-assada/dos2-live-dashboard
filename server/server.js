const express = require("express");
const cors = require("cors");
const fs = require("fs");

const app = express();
const PORT = process.env.PORT || 3000;
const SNAPSHOT_PATH =
  process.env.DOS2_SNAPSHOT_PATH ||
  "/home/alex/.local/share/Steam/steamapps/compatdata/435150/pfx/drive_c/users/steamuser/Documents/Larian Studios/Divinity Original Sin 2 Definitive Edition/Osiris Data/DOS2Dashboard/latest_snapshot.json";
const SNAPSHOT_POLL_MS = Number(process.env.DOS2_SNAPSHOT_POLL_MS || 1000);

app.use(cors());
app.use(express.json({ limit: "5mb" }));

let latestState = {
  updated_at: null,
  party_count: 0,
  party: []
};
let lastSnapshotMtimeMs = 0;

app.post("/update", (req, res) => {
  const payload = req.body;

  if (!payload || typeof payload !== "object") {
    return res.status(400).json({ error: "Invalid JSON payload." });
  }

  latestState = {
    ...latestState,
    ...payload,
    server_received_at: new Date().toISOString()
  };

  return res.json({ ok: true });
});

app.get("/status", (_req, res) => {
  res.json(latestState);
});

app.get("/health", (_req, res) => {
  res.json({ ok: true, now: new Date().toISOString() });
});

function ingestSnapshotFile() {
  try {
    const stat = fs.statSync(SNAPSHOT_PATH);
    if (!stat.isFile() || stat.mtimeMs <= lastSnapshotMtimeMs) {
      return;
    }

    const raw = fs.readFileSync(SNAPSHOT_PATH, "utf8");
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object") {
      return;
    }

    latestState = {
      ...latestState,
      ...parsed,
      server_received_at: new Date().toISOString(),
      source: "snapshot_file"
    };
    lastSnapshotMtimeMs = stat.mtimeMs;
  } catch (_err) {
    // Snapshot file may not exist yet; ignore until DOS2 writes it.
  }
}

setInterval(ingestSnapshotFile, SNAPSHOT_POLL_MS);
ingestSnapshotFile();

app.listen(PORT, () => {
  console.log(`DOS2 dashboard server listening on http://localhost:${PORT}`);
  console.log(`Snapshot bridge: ${SNAPSHOT_PATH}`);
});
