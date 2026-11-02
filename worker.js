/**
 * KHub v2.5 — Cloudflare Worker Backend (worker.js)
 * Live Endpoint: https://khub-api.ethananaya351.workers.dev
 * Bound KV Namespace: KHUB_DATA
 *
 * Supported Routes:
 *   - GET  /status     -> Returns App Store maintenance mode state & message
 *   - POST /status     -> Updates App Store maintenance mode state & message
 *   - POST /heartbeat  -> Receives expanded Kindle telemetry heartbeat & returns current store status
 *   - GET  /heartbeat  -> Fallback query-param heartbeat for legacy clients
 *   - GET  /devices    -> Returns all tracked Kindles with expanded telemetry metrics & fleet summary
 *   - POST /devices/delete -> Removes a device record from KV by ID
 */

const DEFAULT_STATUS = {
  maintenance: false,
  storeMaintenance: false,
  online: true,
  status: "online",
  maintenanceMessage:
    "The KHub App Store is temporarily closed for scheduled maintenance. Please check back soon!",
  updatedAt: 0
};

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers":
    "Content-Type, Authorization, X-Master-Key, X-Access-Key, X-Requested-With",
  "Cache-Control": "no-store, no-cache, must-revalidate, max-age=0"
};

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...CORS_HEADERS
    }
  });
}

function getKvNamespace(env) {
  if (env && env.KHUB_DATA) return env.KHUB_DATA;
  if (typeof KHUB_DATA !== "undefined") return KHUB_DATA;
  return null;
}

async function readStoreStatus(kv) {
  if (!kv) return { ...DEFAULT_STATUS };
  try {
    const raw = await kv.get("status");
    if (raw) {
      const parsed = JSON.parse(raw);
      const isMaint = Boolean(
        parsed.maintenance === true ||
          parsed.storeMaintenance === true ||
          parsed.maintenance === "true" ||
          parsed.storeMaintenance === "true" ||
          parsed.online === false ||
          parsed.status === "maintenance"
      );
      return {
        maintenance: isMaint,
        storeMaintenance: isMaint,
        online: !isMaint,
        status: isMaint ? "maintenance" : "online",
        maintenanceMessage:
          parsed.maintenanceMessage || DEFAULT_STATUS.maintenanceMessage,
        updatedAt: parsed.updatedAt || Date.now()
      };
    }
  } catch (e) {}
  return { ...DEFAULT_STATUS };
}

async function writeStoreStatus(kv, payload) {
  const current = await readStoreStatus(kv);
  let isMaint = current.maintenance;
  if (typeof payload.maintenance !== "undefined") {
    isMaint =
      payload.maintenance === true ||
      payload.maintenance === "true" ||
      payload.maintenance === 1 ||
      payload.maintenance === "1";
  } else if (typeof payload.storeMaintenance !== "undefined") {
    isMaint =
      payload.storeMaintenance === true ||
      payload.storeMaintenance === "true" ||
      payload.storeMaintenance === 1 ||
      payload.storeMaintenance === "1";
  } else if (typeof payload.online !== "undefined") {
    isMaint = !(payload.online === true || payload.online === "true");
  }

  const nextStatus = {
    maintenance: isMaint,
    storeMaintenance: isMaint,
    online: !isMaint,
    status: isMaint ? "maintenance" : "online",
    maintenanceMessage:
      typeof payload.maintenanceMessage === "string" &&
      payload.maintenanceMessage.trim().length > 0
        ? payload.maintenanceMessage.trim()
        : current.maintenanceMessage || DEFAULT_STATUS.maintenanceMessage,
    updatedAt: Date.now()
  };

  if (kv) {
    await kv.put("status", JSON.stringify(nextStatus));
  }
  return nextStatus;
}

async function readDevicesMap(kv) {
  if (!kv) return {};
  try {
    const raw = await kv.get("devices");
    if (raw) {
      const parsed = JSON.parse(raw);
      if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
        return parsed;
      }
    }
  } catch (e) {}
  return {};
}

async function writeDevicesMap(kv, devicesMap) {
  if (!kv) return;
  await kv.put("devices", JSON.stringify(devicesMap));
}

function sanitizeArray(val) {
  if (Array.isArray(val)) return val.map((x) => String(x));
  if (typeof val === "string" && val.trim()) {
    return val
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);
  }
  return [];
}

function normalizeHeartbeatRecord(incoming, existing, request) {
  const now = Date.now();
  const prev = existing && typeof existing === "object" ? existing : {};

  const rawId =
    incoming.id ||
    incoming.trackingId ||
    incoming.deviceId ||
    prev.id ||
    "KNDL-UNKNOWN";
  const id = String(rawId).replace(/[^A-Za-z0-9_-]/g, "") || "KNDL-UNKNOWN";

  const installedAppsList = sanitizeArray(
    incoming.installedAppsList ||
      incoming.installedStoreApps ||
      prev.installedAppsList ||
      prev.installedStoreApps
  );

  const activePlugins = sanitizeArray(
    incoming.activePlugins || prev.activePlugins
  );

  const rssFeedsList = sanitizeArray(
    incoming.rssFeedsList || prev.rssFeedsList
  );

  const installedAppsCount =
    typeof incoming.installedAppsCount === "number"
      ? incoming.installedAppsCount
      : installedAppsList.length;

  const rssFeedsCount =
    typeof incoming.rssFeedsCount === "number"
      ? incoming.rssFeedsCount
      : rssFeedsList.length > 0
      ? rssFeedsList.length
      : typeof prev.rssFeedsCount === "number"
      ? prev.rssFeedsCount
      : 1;

  const activeRssFeedsCount =
    typeof incoming.activeRssFeedsCount === "number"
      ? incoming.activeRssFeedsCount
      : rssFeedsCount;

  const textZoom =
    typeof incoming.textZoom === "number"
      ? incoming.textZoom
      : typeof incoming.zoomLevel === "number"
      ? incoming.zoomLevel
      : typeof prev.textZoom === "number"
      ? prev.textZoom
      : 100;

  const batteryLevel =
    typeof incoming.batteryLevel === "number"
      ? Math.max(0, Math.min(100, Math.round(incoming.batteryLevel)))
      : typeof prev.batteryLevel === "number"
      ? prev.batteryLevel
      : 100;

  const lowPowerMode =
    typeof incoming.lowPowerMode === "boolean"
      ? incoming.lowPowerMode
      : Boolean(prev.lowPowerMode);

  const headerUa =
    request && request.headers ? request.headers.get("User-Agent") || "" : "";
  const cfIp =
    request && request.headers
      ? request.headers.get("CF-Connecting-IP") || ""
      : "";
  const cfCountry =
    request && request.cf && request.cf.country ? request.cf.country : "";

  const userAgent =
    incoming.userAgent || prev.userAgent || headerUa || "Kindle Mesquite";

  const currentScreen =
    incoming.currentScreen ||
    incoming.activeApp ||
    incoming.screen ||
    prev.currentScreen ||
    "launcher-screen";

  const activeApp =
    incoming.activeApp || incoming.currentScreen || prev.activeApp || "KHub Home";

  const ip =
    incoming.ip && incoming.ip !== "Unknown"
      ? String(incoming.ip)
      : prev.ip || cfIp || "Unknown";

  return {
    id,
    trackingId: id,
    name: incoming.name || prev.name || `Kindle (${id})`,
    version: String(incoming.version || prev.version || "2.5"),
    ip,
    publicIp: cfIp || prev.publicIp || "",
    country: cfCountry || prev.country || "",
    currentScreen: String(currentScreen),
    rawScreen: String(
      incoming.rawScreen || incoming.screen || prev.rawScreen || "launcher-screen"
    ),
    activeApp: String(activeApp),
    installedAppsCount,
    installedAppsList,
    installedStoreApps: sanitizeArray(
      incoming.installedStoreApps || installedAppsList
    ),
    activePlugins,
    activePluginsCount: activePlugins.length,
    rssFeedsCount,
    activeRssFeedsCount,
    rssFeedsList,
    loadingMode: String(
      incoming.loadingMode || prev.loadingMode || "Pre-Load (2h)"
    ),
    lowPowerMode,
    batteryLevel,
    textZoom,
    zoomLevel: textZoom,
    hasAiKey:
      typeof incoming.hasAiKey === "boolean"
        ? incoming.hasAiKey
        : Boolean(prev.hasAiKey),
    userAgent: String(userAgent),
    deviceInfo: String(
      incoming.deviceInfo || prev.deviceInfo || parseKindleDeviceInfo(userAgent)
    ),
    uptime: String(incoming.uptime || prev.uptime || "0m"),
    uptimeSeconds:
      typeof incoming.uptimeSeconds === "number"
        ? incoming.uptimeSeconds
        : prev.uptimeSeconds || 0,
    syncTrigger: String(incoming.syncTrigger || "heartbeat"),
    telemetry:
      incoming.telemetry && typeof incoming.telemetry === "object"
        ? incoming.telemetry
        : prev.telemetry || {},
    lastSeen: now,
    clientLastSeen: incoming.lastSeen || now,
    lastSeenReadable:
      incoming.lastSeenReadable || new Date(now).toISOString(),
    firstSeen: prev.firstSeen || now,
    heartbeatCount: (prev.heartbeatCount || 0) + 1
  };
}

function parseKindleDeviceInfo(ua) {
  if (!ua) return "Kindle E-Reader";
  const s = String(ua);
  const fwMatch = s.match(/Version\/([0-9.]+)/i) || s.match(/Kindle\/([0-9.]+)/i);
  const fw = fwMatch ? ` (FW ${fwMatch[1]})` : "";
  if (/Kindle/i.test(s) || /Mesquite/i.test(s) || /Linux\s+armv/i.test(s)) {
    return `Kindle Mesquite WebKit${fw}`;
  }
  if (/Macintosh|Windows|Linux|iPhone|Android/i.test(s)) {
    return `Browser / Simulator${fw}`;
  }
  return `Kindle Device${fw}`;
}

async function handleRequest(request, env) {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  const kv = getKvNamespace(env);
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, "") || "/";

  try {
    // 1. GET / POST /status (Maintenance Switch & Store Status)
    if (path === "/" || path === "/status") {
      if (request.method === "POST" || request.method === "PUT") {
        let body = {};
        try {
          body = await request.json();
        } catch (e) {
          body = Object.fromEntries(url.searchParams.entries());
        }
        const updated = await writeStoreStatus(kv, body);
        return jsonResponse({ ok: true, ...updated });
      }

      // Allow query-param toggle via GET /status?setMaintenance=true|false if needed
      if (url.searchParams.has("setMaintenance")) {
        const updated = await writeStoreStatus(kv, {
          maintenance: url.searchParams.get("setMaintenance"),
          maintenanceMessage: url.searchParams.get("maintenanceMessage") || ""
        });
        return jsonResponse({ ok: true, ...updated });
      }

      const status = await readStoreStatus(kv);
      return jsonResponse({ ok: true, ...status });
    }

    // 2. POST (or GET fallback) /heartbeat (Kindle Device Telemetry Heartbeat)
    if (path === "/heartbeat") {
      let incoming = {};
      if (request.method === "POST" || request.method === "PUT") {
        try {
          const text = await request.text();
          if (text) {
            incoming = JSON.parse(text);
          }
        } catch (e) {}
      }
      if (!incoming || Object.keys(incoming).length === 0) {
        incoming = Object.fromEntries(url.searchParams.entries());
        if (incoming.payload) {
          try {
            incoming = JSON.parse(incoming.payload);
          } catch (e) {}
        }
      }

      const devicesMap = await readDevicesMap(kv);
      const rawId =
        incoming.id || incoming.trackingId || incoming.deviceId || "KNDL-UNKNOWN";
      const cleanId =
        String(rawId).replace(/[^A-Za-z0-9_-]/g, "") || "KNDL-UNKNOWN";

      const record = normalizeHeartbeatRecord(
        incoming,
        devicesMap[cleanId],
        request
      );
      devicesMap[cleanId] = record;
      await writeDevicesMap(kv, devicesMap);

      const status = await readStoreStatus(kv);
      return jsonResponse({
        ok: true,
        device: record,
        maintenance: status.maintenance,
        storeMaintenance: status.storeMaintenance,
        maintenanceMessage: status.maintenanceMessage
      });
    }

    // 3. GET /devices (Admin Panel Device List & Summary Metrics)
    if (path === "/devices") {
      const [devicesMap, status] = await Promise.all([
        readDevicesMap(kv),
        readStoreStatus(kv)
      ]);
      const now = Date.now();
      const ONLINE_WINDOW_MS = 75 * 60 * 1000; // 75 minutes (covers 1h-2h preload & active sessions)
      const ACTIVE_NOW_MS = 15 * 60 * 1000; // 15 minutes

      const devicesList = Object.values(devicesMap)
        .filter((d) => d && typeof d === "object")
        .map((d) => {
          const ageMs = Math.max(0, now - (d.lastSeen || 0));
          return {
            ...d,
            isOnline: ageMs <= ONLINE_WINDOW_MS,
            isActiveNow: ageMs <= ACTIVE_NOW_MS,
            ageSeconds: Math.floor(ageMs / 1000)
          };
        })
        .sort((a, b) => (b.lastSeen || 0) - (a.lastSeen || 0));

      return jsonResponse({
        ok: true,
        now,
        maintenance: status.maintenance,
        storeMaintenance: status.storeMaintenance,
        maintenanceMessage: status.maintenanceMessage,
        totalDevices: devicesList.length,
        onlineDevices: devicesList.filter((d) => d.isOnline).length,
        activeNowDevices: devicesList.filter((d) => d.isActiveNow).length,
        devices: devicesMap,
        devicesList
      });
    }

    // 4. POST / DELETE /devices/delete (Admin Panel Device Cleanup / Rename)
    if (path === "/devices/delete" || path === "/devices/remove") {
      let body = {};
      try {
        body = await request.json();
      } catch (e) {
        body = Object.fromEntries(url.searchParams.entries());
      }
      const targetId = String(body.id || url.searchParams.get("id") || "").replace(
        /[^A-Za-z0-9_-]/g,
        ""
      );
      const devicesMap = await readDevicesMap(kv);
      if (targetId && devicesMap[targetId]) {
        delete devicesMap[targetId];
        await writeDevicesMap(kv, devicesMap);
      }
      return jsonResponse({ ok: true, deletedId: targetId });
    }

    if (path === "/devices/rename") {
      let body = {};
      try {
        body = await request.json();
      } catch (e) {
        body = Object.fromEntries(url.searchParams.entries());
      }
      const targetId = String(body.id || "").replace(/[^A-Za-z0-9_-]/g, "");
      const newName = String(body.name || "").trim();
      const devicesMap = await readDevicesMap(kv);
      if (targetId && devicesMap[targetId] && newName) {
        devicesMap[targetId].name = newName;
        await writeDevicesMap(kv, devicesMap);
      }
      return jsonResponse({
        ok: true,
        device: devicesMap[targetId] || null
      });
    }

    return jsonResponse(
      { ok: false, error: "Route not found", path },
      404
    );
  } catch (err) {
    return jsonResponse(
      {
        ok: false,
        error: err && err.message ? err.message : "Internal Worker Error"
      },
      500
    );
  }
}

export default {
  async fetch(request, env, ctx) {
    return handleRequest(request, env);
  }
};
