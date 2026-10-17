(function () {
  const S = window.DSHPetShared;
  const Q = window.PetQuotes;
  const api = window.pet;

  const petEl = document.getElementById("pet");
  const bubbleEl = document.getElementById("bubble");
  const artEl = document.getElementById("bubble-art");
  const linesEl = document.getElementById("bubble-lines");
  const gifEl = document.getElementById("bubble-gif");

  let cfg = null;
  let lay = null;
  let st = { mirror: false, placeRight: true, snapRight: true };
  let modelUrl = "";
  let assetBase = "";
  let platform = "";
  let balances = [];

  let bubbleVisible = false;
  let bubbleMode = "";
  let closeTimer = null;
  let idleTimer = null;

  let downButton = null;
  let dragStarted = false;
  let startScreen = { x: 0, y: 0 };
  let squishing = false;

  let lastMouse = { x: -1, y: -1 };
  let lastIgnore = null;
  let audioCache = new Map();

  function setPetTransform() {
    if (!petEl) return;
    const sx = squishing ? 1.07 : 1;
    const sy = squishing ? 0.9 : 1;
    const mirror = st.mirror ? -1 : 1;
    petEl.style.transform = "scaleX(" + mirror + ") scale(" + sx + ", " + sy + ")";
  }

  function applyLayout() {
    if (!lay || !cfg) return;

    petEl.style.width = lay.whaleW + "px";
    petEl.style.height = lay.whaleH + "px";
    petEl.style.left = (st.placeRight ? lay.width - lay.whaleW - lay.edgePad : lay.edgePad) + "px";
    setPetTransform();

    const bubbleTop = lay.whaleTop - lay.artH - 8;
    bubbleEl.style.top = bubbleTop + "px";
    bubbleEl.style.width = lay.width + "px";
    bubbleEl.style.height = lay.artH + "px";
    bubbleEl.style.transformOrigin = (st.placeRight ? "100% 100%" : "0% 100%");

    artEl.style.width = lay.artW + "px";
    artEl.style.height = lay.artH + "px";
    artEl.classList.toggle("mirror", !!st.placeRight);

    const svg = artEl.querySelector("svg");
    if (svg) {
      svg.setAttribute("width", String(1026 * lay.artScale));
      svg.setAttribute("height", String(700 * lay.artScale));
    }

    linesEl.style.width = (677 * lay.artScale) + "px";
    linesEl.style.left = "50%";
    linesEl.style.top = (247 * lay.artScale) + "px";
    linesEl.style.fontSize = Math.max(9, Math.round(19 * lay.width / 229)) + "px";

    const gifSize = Math.min(lay.width * 0.55, lay.artH * 0.55);
    gifEl.style.width = gifSize + "px";
    gifEl.style.height = gifSize + "px";
    gifEl.style.top = (lay.artH * 0.32) + "px";

    requestAnimationFrame(recheckMouse);
  }

  function buildBubbleArt() {
    const NS = "http://www.w3.org/2000/svg";
    const svg = document.createElementNS(NS, "svg");
    svg.setAttribute("viewBox", "0 0 1026 700");
    svg.setAttribute("preserveAspectRatio", "xMinYMin meet");

    const g = document.createElementNS(NS, "g");
    g.setAttribute("transform", "translate(-60,0)");

    const paths = [S.BUBBLE_PATH_MAIN, S.BUBBLE_PATH_DOT1, S.BUBBLE_PATH_DOT2];
    for (const d of paths) {
      const p = document.createElementNS(NS, "path");
      p.setAttribute("d", d);
      p.setAttribute("fill", "#ffffff");
      p.setAttribute("stroke", "#203170");
      p.setAttribute("stroke-width", "18");
      p.setAttribute("stroke-linecap", "round");
      p.setAttribute("stroke-linejoin", "round");
      g.appendChild(p);
    }
    svg.appendChild(g);
    artEl.appendChild(svg);
  }

  function renderLines(lines) {
    linesEl.replaceChildren();
    for (const line of lines) {
      const div = document.createElement("div");
      div.className = "line";
      const text = (line.s === "P" ? "\u25CF  " : "") + line.t;
      div.textContent = text;
      if (line.c) div.style.color = line.c;
      linesEl.appendChild(div);
    }
  }

  function showBubble(lines, mode) {
    bubbleMode = mode || "";
    if (lines === null) {
      gifEl.src = assetBase + "rua.gif";
      bubbleEl.classList.add("gif");
    } else {
      bubbleEl.classList.remove("gif");
      renderLines(Array.isArray(lines) && lines.length ? lines : [{ t: "...(鲸鱼娘走神了)", s: "A", c: "" }]);
    }
    bubbleEl.classList.add("show");
    bubbleEl.setAttribute("aria-hidden", "false");
    bubbleVisible = true;
    clearTimeout(closeTimer);
    closeTimer = setTimeout(closeBubble, 5000);
    requestAnimationFrame(recheckMouse);
  }

  function closeBubble() {
    clearTimeout(closeTimer);
    closeTimer = null;
    bubbleVisible = false;
    bubbleMode = "";
    bubbleEl.classList.remove("show");
    bubbleEl.setAttribute("aria-hidden", "true");
    requestAnimationFrame(recheckMouse);
  }

  function refreshBalanceBubble() {
    if (!bubbleVisible || bubbleMode !== "balance") return;
    bubbleEl.classList.remove("gif");
    renderLines(Q.group1(balances));
  }

  function applyState(next) {
    if (!next) return;
    st = Object.assign({}, st, next);
    applyLayout();
  }

  function applyConfigPayload(payload) {
    cfg = payload.config;
    lay = payload.layout;
    modelUrl = payload.modelUrl;
    assetBase = payload.assetsUrl;
    applyModel();
    applyLayout();
    restartIdle();
  }

  let lastModel = "";
  function applyModel() {
    if (!modelUrl || lastModel === modelUrl) return;
    lastModel = modelUrl;
    petEl.src = modelUrl;
  }

  function playSfx(kind) {
    if (!cfg || !cfg.sound) return;
    const file = cfg.soundSet === "duck"
      ? (kind === "press" ? "Ya1.mp3" : "Ya2.mp3")
      : (kind === "press" ? "D1.mp3" : "D2.mp3");
    try {
      let a = audioCache.get(file);
      if (!a) {
        a = new Audio(assetBase + file);
        a.preload = "auto";
        audioCache.set(file, a);
      }
      a.volume = Math.max(0, Math.min(1, cfg.volume));
      a.currentTime = 0;
      a.play().catch(() => {});
    } catch (_) {}
  }

  function restartIdle() {
    clearTimeout(idleTimer);
    idleTimer = null;
    if (!cfg || !cfg.idleTalk) return;
    const base = Math.max(1, cfg.idleTalkMinutes) * 60000;
    const schedule = () => {
      idleTimer = setTimeout(() => {
        const busy = downButton !== null || dragStarted;
        if (!busy && !bubbleVisible && Math.random() < cfg.idleTalkChance) {
          showBubble(Q.random(balances));
        }
        schedule();
      }, base * (0.5 + Math.random()));
    };
    schedule();
  }

  function isInteractiveAt(x, y) {
    const el = document.elementFromPoint(x, y);
    if (!el) return false;
    if (el.closest("#pet")) return true;
    if (bubbleVisible && el.closest("#bubble")) return true;
    return false;
  }

  function setIgnore(ignore) {
    if (ignore === lastIgnore) return;
    lastIgnore = ignore;
    api.setIgnoreMouse(ignore);
  }

  function recheckMouse() {
    if (lastMouse.x < 0) return;
    // 拖拽期间保持可交互,避免指针跑出宠物后触发点击穿透
    if (downButton !== null || dragStarted) return;
    setIgnore(!isInteractiveAt(lastMouse.x, lastMouse.y));
  }

  function squishDown() {
    squishing = true;
    petEl.classList.remove("bounce");
    setPetTransform();
  }

  function squishUp() {
    squishing = false;
    petEl.classList.add("bounce");
    setPetTransform();
    setTimeout(() => petEl.classList.remove("bounce"), 460);
  }

  function cycleModel() {
    api.cycleModel().catch(() => {});
  }

  async function finishDrag(pointerId) {
    try { petEl.releasePointerCapture(pointerId); } catch (_) {}
    if (dragStarted) {
      petEl.classList.remove("dragging");
      const next = await api.endDrag();
      applyState(next);
      dragStarted = false;
    }
    downButton = null;
  }

  petEl.addEventListener("pointerdown", (e) => {
    if (e.button !== 0 && e.button !== 1 && e.button !== 2) return;
    e.preventDefault();
    downButton = e.button;
    dragStarted = false;
    startScreen = { x: e.screenX, y: e.screenY };
    try { petEl.setPointerCapture(e.pointerId); } catch (_) {}
    squishDown();
    playSfx("press");
  });

  petEl.addEventListener("pointermove", (e) => {
    if (downButton === null) return;
    if (!dragStarted && (Math.abs(e.screenX - startScreen.x) > 4 || Math.abs(e.screenY - startScreen.y) > 4)) {
      dragStarted = true;
      petEl.classList.add("dragging");
      api.beginDrag();
      api.dragMove();
    } else if (dragStarted) {
      api.dragMove();
    }
  });

  petEl.addEventListener("pointerup", async (e) => {
    if (downButton === null) return;
    const button = downButton;
    const wasDrag = dragStarted;
    playSfx("release");
    squishUp();
    await finishDrag(e.pointerId);
    recheckMouse();
    if (wasDrag) return;
    if (button === 1) {
      cycleModel();
    } else if (button === 2) {
      if (bubbleVisible) closeBubble();
      else {
        api.refreshBalances();
        showBubble(Q.group1(balances), "balance");
      }
    } else {
      showBubble(Q.random(balances));
    }
  });

  petEl.addEventListener("pointercancel", async (e) => {
    if (downButton === null) return;
    playSfx("release");
    squishUp();
    await finishDrag(e.pointerId);
    recheckMouse();
  });

  petEl.addEventListener("contextmenu", (e) => e.preventDefault());
  petEl.addEventListener("dragstart", (e) => e.preventDefault());
  petEl.addEventListener("error", () => {
    showBubble([{ t: "模型加载失败：" + (cfg ? cfg.model : ""), s: "A", c: "#c25b5b" }]);
  });

  bubbleEl.addEventListener("pointerdown", (e) => e.stopPropagation());
  bubbleEl.addEventListener("click", () => showBubble(Q.random(balances)));

  document.addEventListener("mousemove", (e) => {
    lastMouse = { x: e.clientX, y: e.clientY };
    recheckMouse();
  });
  window.addEventListener("mouseout", (e) => {
    if (!e.relatedTarget && downButton === null && !dragStarted) {
      lastMouse = { x: -1, y: -1 };
      setIgnore(true);
    }
  });
  window.addEventListener("blur", () => {
    if (!dragStarted) {
      lastMouse = { x: -1, y: -1 };
      setIgnore(true);
    }
  });
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") closeBubble();
  });

  api.onConfig((payload) => applyConfigPayload(payload));
  api.onState((next) => applyState(next));
  api.onBalances((data) => {
    balances = Array.isArray(data) ? data : [];
    refreshBalanceBubble();
  });
  api.onModel((payload) => {
    applyModel();
    if (payload && payload.announce) {
      showBubble([{ t: "换装完成：" + payload.label, s: "A", c: "" }]);
    }
  });
  api.onSay((text) => showBubble([{ t: String(text), s: "A", c: "" }]));

  (async function boot() {
    try {
      const data = await api.bootstrap();
      platform = data.platform;
      balances = (await api.getBalances()) || [];
      buildBubbleArt();
      applyConfigPayload(data);
      applyState(data.state);
      lastIgnore = null;
      document.body.dataset.platform = platform || "";
    } catch (e) {
      showBubble([{ t: "启动失败：" + (e && e.message ? e.message : e), s: "A", c: "#c25b5b" }]);
    }
  })();
})();
