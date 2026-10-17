const { app, BrowserWindow, ipcMain, screen, Tray, Menu, nativeImage, shell, net } = require("electron");
const path = require("node:path");
const fs = require("node:fs");
const { pathToFileURL } = require("node:url");
const S = require("./shared");

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.setAppUserModelId("com.setsuna391.dshpet");
  Menu.setApplicationMenu(null);

  let win = null;
  let tray = null;
  let cfg, lay, state;
  let isQuitting = false;
  let cfgWatch = null;
  let balTimer = null;
  let balBusy = false;
  let balances = [];
  let drag = null;
  let xAnim = null;
  let userDir = "";
  let cfgPath = "";
  let statePath = "";
  let logPath = "";
  let assetsDir = "";

  const DEFAULT_STATE = { x: null, mirrored: false, snapRight: true, placeRight: true };

  function initPaths() {
    userDir = app.getPath("userData");
    cfgPath = path.join(userDir, "config.json");
    statePath = path.join(userDir, "state.json");
    logPath = path.join(userDir, "app.log");
    assetsDir = app.isPackaged
      ? path.join(process.resourcesPath, "assets")
      : path.join(__dirname, "..", "assets");
    fs.mkdirSync(userDir, { recursive: true });
  }

  function log(...args) {
    try {
      const line = new Date().toISOString() + " " + args.map(String).join(" ") + "\n";
      fs.appendFileSync(logPath, line);
      const st = fs.statSync(logPath);
      if (st.size > 256 * 1024) {
        const tail = fs.readFileSync(logPath, "utf8").slice(-128 * 1024);
        fs.writeFileSync(logPath, tail);
      }
    } catch (_) {}
  }

  function readJson(file, fallback) {
    try {
      return JSON.parse(fs.readFileSync(file, "utf8"));
    } catch (_) {
      return fallback;
    }
  }

  function writeJson(file, obj) {
    const tmp = file + ".tmp";
    fs.writeFileSync(tmp, JSON.stringify(obj, null, 2));
    fs.renameSync(tmp, file);
  }

  function loadConfig() {
    if (!fs.existsSync(cfgPath)) {
      try { writeJson(cfgPath, S.defaultConfig()); } catch (e) { log("write default config failed", e); }
    }
    return S.normalizeConfig(readJson(cfgPath, {}));
  }

  function loadState() {
    const raw = readJson(statePath, {});
    const st = Object.assign({}, DEFAULT_STATE);
    if (typeof raw.x === "number" && isFinite(raw.x)) st.x = raw.x;
    if (typeof raw.mirrored === "boolean") st.mirrored = raw.mirrored;
    if (typeof raw.snapRight === "boolean") st.snapRight = raw.snapRight;
    if (typeof raw.placeRight === "boolean") st.placeRight = raw.placeRight;
    if (st.snapRight) st.placeRight = true;
    return st;
  }

  function saveState() {
    try {
      writeJson(statePath, {
        x: state.x,
        mirrored: state.mirrored,
        snapRight: state.snapRight,
        placeRight: state.placeRight,
      });
    } catch (e) { log("save state failed", e); }
  }

  function saveConfigPatch(patch) {
    try {
      const raw = readJson(cfgPath, {});
      Object.assign(raw, patch);
      writeJson(cfgPath, raw);
    } catch (e) { log("save config failed", e); }
  }

  function resolveModelUrl(model) {
    const m = String(model || "DSniang1.png");
    const abs = path.isAbsolute(m) || /^[A-Za-z]:[\\/]/.test(m) || m.startsWith("\\\\");
    return pathToFileURL(abs ? m : path.join(assetsDir, m)).href;
  }

  function displayFor(cfg) {
    const displays = screen.getAllDisplays();
    const name = (cfg.screen || "").trim();
    if (name) {
      const byLabel = displays.find((d) => (d.label || "").toLowerCase().includes(name.toLowerCase()));
      if (byLabel) return byLabel;
      const idx = parseInt(name, 10);
      if (!isNaN(idx) && displays[idx]) return displays[idx];
    }
    return screen.getPrimaryDisplay();
  }

  function targetX(display) {
    const wa = display.workArea;
    const maxX = wa.x + wa.width - lay.width;
    if (state.snapRight) return maxX;
    if (state.mirrored) return wa.x;
    const x = typeof state.x === "number" ? state.x : maxX;
    return S.clamp(x, wa.x, maxX);
  }

  function applyWindowPosition(display, x) {
    const wa = display.workArea;
    const y = wa.y + wa.height - lay.height;
    win.setBounds({ x: Math.round(x), y, width: lay.width, height: lay.height });
  }

  function publicState() {
    return {
      mirror: !!state.mirrored,
      snapRight: !!state.snapRight,
      placeRight: !!state.placeRight,
      x: win ? win.getBounds().x : state.x,
    };
  }

  function sendState() {
    if (win && !win.isDestroyed()) win.webContents.send("state-changed", publicState());
  }

  function sendConfig(extra) {
    if (!win || win.isDestroyed()) return;
    win.webContents.send("config-changed", Object.assign({
      config: cfg,
      layout: lay,
      modelUrl: resolveModelUrl(cfg.model),
      assetsUrl: pathToFileURL(assetsDir + path.sep).href,
      userDir,
    }, extra || {}));
  }

  function animateX(target) {
    if (xAnim) clearInterval(xAnim);
    const start = win.getBounds().x;
    const y = win.getBounds().y;
    if (start === target) return;
    const t0 = Date.now();
    xAnim = setInterval(() => {
      if (!win || win.isDestroyed()) { clearInterval(xAnim); xAnim = null; return; }
      const k = Math.min(1, (Date.now() - t0) / 180);
      const e = 1 - Math.pow(1 - k, 3);
      win.setPosition(Math.round(start + (target - start) * e), y);
      if (k >= 1) { clearInterval(xAnim); xAnim = null; }
    }, 10);
  }

  function applyLayout() {
    const display = displayFor(cfg);
    const wa = display.workArea;
    const maxX = wa.x + wa.width - lay.width;
    state.x = S.clamp(targetX(display), wa.x, maxX);
    applyWindowPosition(display, state.x);
  }

  function setModel(name, announce) {
    let m = String(name || "").trim();
    if (!m || m === "default") m = "DSniang1.png";
    cfg.model = m;
    sendConfig();
    if (announce) win.webContents.send("model-changed", { model: m, label: S.modelLabel(m), announce: true });
    saveConfigPatch({ model: m });
    buildTray();
  }

  function cycleModel() {
    const list = (cfg.models && cfg.models.length) ? cfg.models : S.DEFAULT_MODELS;
    const i = list.indexOf(cfg.model);
    const next = list[(i + 1) % list.length];
    setModel(next, true);
    return cfg.model;
  }

  function buildTray() {
    if (!tray) {
      let icon = nativeImage.createFromPath(path.join(assetsDir, "DSniang1.png"));
      if (!icon.isEmpty()) icon = icon.resize({ width: 16, height: 16 });
      tray = new Tray(icon);
      tray.setToolTip("DSH 桌面宠物");
      tray.on("click", toggleWindow);
    }
    const modelItems = ((cfg.models && cfg.models.length) ? cfg.models : S.DEFAULT_MODELS).map((m) => ({
      label: S.modelLabel(m),
      type: "radio",
      checked: cfg.model === m,
      click: () => setModel(m, true),
    }));
    const menu = Menu.buildFromTemplate([
      { label: win && win.isVisible() ? "隐藏" : "显示", click: toggleWindow },
      { label: "换模型", submenu: modelItems },
      { type: "separator" },
      {
        label: "音效", type: "checkbox", checked: cfg.sound,
        click: (item) => { cfg.sound = item.checked; saveConfigPatch({ sound: cfg.sound }); sendConfig(); },
      },
      {
        label: "发呆自言自语", type: "checkbox", checked: cfg.idleTalk,
        click: (item) => { cfg.idleTalk = item.checked; saveConfigPatch({ idleTalk: cfg.idleTalk }); sendConfig(); },
      },
      { type: "separator" },
      { label: "打开配置文件夹", click: () => shell.openPath(userDir) },
      { label: "重新读取配置", click: () => applyConfigFromDisk(true) },
      { type: "separator" },
      { label: "退出", click: () => { isQuitting = true; app.quit(); } },
    ]);
    tray.setContextMenu(menu);
  }

  function toggleWindow() {
    if (!win) return;
    if (win.isVisible()) win.hide();
    else { win.showInactive(); if (process.platform === "win32") win.setIgnoreMouseEvents(true, { forward: true }); }
    buildTray();
  }

  function applyConfigFromDisk(force) {
    const next = loadConfig();
    const old = cfg;
    if (!force && JSON.stringify(next) === JSON.stringify(old)) return;
    cfg = next;
    lay = S.layout(cfg);
    applyLayout();
    sendConfig();
    buildTray();
    if (JSON.stringify(old.balance) !== JSON.stringify(cfg.balance)) startBalances();
    if (old.model !== cfg.model && win && !win.isDestroyed()) {
      win.webContents.send("model-changed", { model: cfg.model, label: S.modelLabel(cfg.model), announce: false });
    }
  }

  function startConfigWatch() {
    if (cfgWatch) fs.unwatchFile(cfgPath);
    fs.watchFile(cfgPath, { interval: 1000 }, (curr, prev) => {
      if (curr.mtimeMs !== prev.mtimeMs) applyConfigFromDisk(false);
    });
    cfgWatch = true;
  }

  function keyFor(src) {
    if (src.apiKey) return src.apiKey;
    const fileMap = { deepseek: "api_key", openrouter: "openrouter_key", siliconflow: "siliconflow_key" };
    const envMap = { deepseek: "DEEPSEEK_API_KEY", openrouter: "OPENROUTER_API_KEY", siliconflow: "SILICONFLOW_API_KEY" };
    try {
      const k = fs.readFileSync(path.join(userDir, fileMap[src.type] || ""), "utf8").trim();
      if (k) return k;
    } catch (_) {}
    return (process.env[envMap[src.type]] || "").trim();
  }

  async function fetchOne(src) {
    const base = { name: src.name, amount: "--", currency: "", ok: false, err: false };
    const key = keyFor(src);
    if (!key) return base;

    let url = "";
    if (src.type === "deepseek") url = "https://api.deepseek.com/user/balance";
    else if (src.type === "openrouter") url = "https://openrouter.ai/api/v1/credits";
    else if (src.type === "siliconflow") url = "https://api.siliconflow.cn/v1/user/info";
    else return base;

    try {
      const res = await net.fetch(url, {
        headers: { Authorization: "Bearer " + key },
        signal: AbortSignal.timeout(8000),
      });
      let j = null;
      try { j = await res.json(); } catch (_) {}
      const out = Object.assign({}, base);
      if (res.ok && j) {
        if (src.type === "deepseek" && Array.isArray(j.balance_infos) && j.balance_infos.length) {
          out.amount = parseFloat(j.balance_infos[0].total_balance).toFixed(2);
          out.currency = j.balance_infos[0].currency || "CNY";
          out.ok = true;
        } else if (src.type === "openrouter" && j.data && typeof j.data.total_credits === "number") {
          out.amount = (j.data.total_credits - (j.data.total_usage || 0)).toFixed(2);
          out.currency = "USD";
          out.ok = true;
        } else if (src.type === "siliconflow" && j.data) {
          const bal = parseFloat(j.data.balance);
          if (!isNaN(bal)) { out.amount = bal.toFixed(2); out.currency = "CNY"; out.ok = true; }
        }
      }
      if (!out.ok) {
        out.err = true;
        if (res.status === 401 || res.status === 403) out.amount = "key 无效";
        else if (res.status === 429) out.amount = "请求限流";
        else if (res.status >= 500) out.amount = "连接失败";
        else out.amount = "HTTP " + res.status;
      }
      return out;
    } catch (e) {
      log("balance fetch failed", src.type, e && e.message);
      return Object.assign({}, base, { amount: "连接失败", err: true });
    }
  }

  async function refreshBalances() {
    if (balBusy) return;
    balBusy = true;
    const results = [];
    for (const src of cfg.balance) results.push(await fetchOne(src));
    balances = results;
    if (win && !win.isDestroyed()) win.webContents.send("balances", balances);
    balBusy = false;
  }

  function startBalances() {
    if (balTimer) { clearInterval(balTimer); balTimer = null; }
    const names = cfg.balance.map((b) => b.name);
    balances = names.map((name) => ({ name, amount: "--", currency: "", ok: false, err: false }));
    refreshBalances();
    balTimer = setInterval(refreshBalances, 60000);
  }

  function onDragStart() {
    if (!win) return;
    const p = screen.getCursorScreenPoint();
    const b = win.getBounds();
    drag = { cursor: p, winX: b.x, winY: b.y, x: b.x };
  }

  function onDragMove() {
    if (!drag || !win) return;
    const display = displayFor(cfg);
    const wa = display.workArea;
    const p = screen.getCursorScreenPoint();
    const maxX = wa.x + wa.width - lay.width;
    const nx = S.clamp(drag.winX + (p.x - drag.cursor.x), wa.x, maxX);
    drag.x = nx;
    win.setPosition(Math.round(nx), drag.winY);
  }

  function onDragEnd() {
    if (!drag || !win) return publicState();
    const display = displayFor(cfg);
    const wa = display.workArea;
    const x = win.getBounds().x;
    const maxX = wa.x + wa.width - lay.width;
    const snapLeft = wa.x + wa.width * cfg.snapZone;
    const snapRight = wa.x + wa.width * (1 - cfg.snapZone) - lay.width;

    if (x < snapLeft) {
      state.mirrored = true; state.snapRight = false; state.placeRight = false;
      state.x = wa.x;
      animateX(wa.x);
    } else if (x > snapRight) {
      state.mirrored = false; state.snapRight = true; state.placeRight = true;
      state.x = maxX;
      animateX(maxX);
    } else {
      state.mirrored = false; state.snapRight = false;
      state.x = S.clamp(x, wa.x, maxX);
    }
    drag = null;
    saveState();
    sendState();
    buildTray();
    return publicState();
  }

  function createWindow() {
    lay = S.layout(cfg);
    state = loadState();
    const display = displayFor(cfg);
    const wa = display.workArea;
    const x = S.clamp(targetX(display), wa.x, wa.x + wa.width - lay.width);
    state.x = x;

    win = new BrowserWindow({
      x: Math.round(x),
      y: wa.y + wa.height - lay.height,
      width: lay.width,
      height: lay.height,
      frame: false,
      transparent: true,
      backgroundColor: "#00000000",
      alwaysOnTop: true,
      skipTaskbar: true,
      resizable: false,
      maximizable: false,
      minimizable: false,
      fullscreenable: false,
      hasShadow: false,
      show: false,
      thickFrame: false,
      focusable: true,
      icon: path.join(assetsDir, "DSniang1.png"),
      webPreferences: {
        preload: path.join(__dirname, "preload.js"),
        contextIsolation: true,
        nodeIntegration: false,
        sandbox: false,
        backgroundThrottling: false,
      },
    });
    win.setAlwaysOnTop(true, "floating");
    win.setSkipTaskbar(true);
    win.loadFile(path.join(__dirname, "renderer", "index.html"));

    win.once("ready-to-show", () => {
      win.showInactive();
      if (process.platform === "win32") win.setIgnoreMouseEvents(true, { forward: true });
      if (process.argv.includes("--demo")) {
        const sayDemo = () => {
          if (win && !win.isDestroyed()) win.webContents.send("say", "Windows 11 版已启动~");
        };
        setTimeout(sayDemo, 800);
        setInterval(sayDemo, 2000);
      }
    });
    win.on("close", (e) => {
      if (!isQuitting) {
        e.preventDefault();
        win.hide();
        buildTray();
      }
    });
    win.on("show", buildTray);
    win.on("hide", buildTray);
    win.webContents.setWindowOpenHandler(() => ({ action: "deny" }));
    win.webContents.on("will-navigate", (e) => e.preventDefault());
    win.webContents.on("render-process-gone", (_e, details) => {
      log("render process gone", details && details.reason);
      if (!isQuitting && win && !win.isDestroyed()) win.reload();
    });
  }

  ipcMain.handle("bootstrap", () => ({
    config: cfg,
    layout: lay,
    state: publicState(),
    modelUrl: resolveModelUrl(cfg.model),
    assetsUrl: pathToFileURL(assetsDir + path.sep).href,
    userDir,
    platform: process.platform,
    version: app.getVersion(),
  }));

  ipcMain.on("set-ignore-mouse", (_e, ignore) => {
    if (process.platform !== "win32" || !win || win.isDestroyed()) return;
    win.setIgnoreMouseEvents(!!ignore, { forward: true });
  });
  ipcMain.on("drag-start", onDragStart);
  ipcMain.on("drag-move", onDragMove);
  ipcMain.handle("drag-end", onDragEnd);
  ipcMain.handle("set-model", (_e, name) => { setModel(name, true); return cfg.model; });
  ipcMain.handle("cycle-model", () => cycleModel());
  ipcMain.handle("get-model", () => cfg.model);
  ipcMain.handle("get-balances", () => balances);
  ipcMain.on("refresh-balances", refreshBalances);
  ipcMain.handle("get-state", () => publicState());
  ipcMain.handle("open-config", () => shell.openPath(userDir));
  ipcMain.on("quit", () => { isQuitting = true; app.quit(); });

  app.on("second-instance", () => {
    if (!win) return;
    if (!win.isVisible()) win.showInactive();
    win.moveTop();
  });

  app.on("before-quit", () => {
    isQuitting = true;
    if (cfgWatch) fs.unwatchFile(cfgPath);
    if (balTimer) clearInterval(balTimer);
    if (xAnim) clearInterval(xAnim);
  });

  app.on("window-all-closed", () => {});

  app.whenReady().then(() => {
    initPaths();
    cfg = loadConfig();
    state = loadState();
    lay = S.layout(cfg);
    balances = (cfg.balance || []).map((b) => ({ name: b.name, amount: "--", currency: "", ok: false, err: false }));
    createWindow();
    buildTray();
    startConfigWatch();
    startBalances();

    const reflow = () => {
      if (!win || win.isDestroyed()) return;
      lay = S.layout(cfg);
      applyLayout();
      sendConfig();
    };
    screen.on("display-added", reflow);
    screen.on("display-removed", reflow);
    screen.on("display-metrics-changed", reflow);
    log("started", app.getVersion(), process.platform, assetsDir);
  });
}
