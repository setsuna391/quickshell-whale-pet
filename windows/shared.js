// 共享的布局/配置逻辑:主进程和渲染进程都用这一份,避免两边公式不一致。
(function (root, factory) {
  if (typeof module === "object" && module.exports) module.exports = factory();
  else root.DSHPetShared = factory();
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  const BASE_W = 170;
  const ART_W = 790;
  const ART_H = 690;

  const BUBBLE_PATH_MAIN = "M 827 248 A 373 232 0 1 0 81 246 A 373 232 0 0 0 301 465 A 57 32 10 0 0 413 484 A 373 232 0 0 0 827 248 Z";
  const BUBBLE_PATH_DOT1 = "M 314.5 561 a 37.5 26 0 1 0 75 0 a 37.5 26 0 1 0 -75 0 Z";
  const BUBBLE_PATH_DOT2 = "M 417.5 646 a 24.5 18 0 1 0 49 0 a 24.5 18 0 1 0 -49 0 Z";

  function num(v, d) { return typeof v === "number" && isFinite(v) ? v : d; }
  function bool(v, d) { return typeof v === "boolean" ? v : d; }
  function str(v) { return typeof v === "string" ? v : ""; }
  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

  const DEFAULT_MODELS = ["DSniang1.png", "characters/xiaoke.png", "characters/gptniang.png"];

  function defaultConfig() {
    return {
      scale: 1, sound: true, soundSet: "duck", volume: 1,
      model: "DSniang1.png", models: DEFAULT_MODELS.slice(),
      edgePad: 3, snapZone: 0.22,
      idleTalk: true, idleTalkMinutes: 5, idleTalkChance: 0.4,
      bubbleScale: 1.3, screen: "",
      balance: [{ name: "DeepSeek", type: "deepseek", apiKey: "" }],
    };
  }

  function normalizeConfig(raw) {
    const j = raw && typeof raw === "object" ? raw : {};
    let models = Array.isArray(j.models)
      ? j.models.filter((m) => typeof m === "string" && m.length > 0)
      : DEFAULT_MODELS.slice();
    if (models.length === 0) models = DEFAULT_MODELS.slice();

    let balance = [];
    if (Array.isArray(j.balance)) {
      for (const b of j.balance) {
        if (!b || typeof b !== "object" || typeof b.type !== "string") continue;
        balance.push({
          name: str(b.name) || b.type,
          type: b.type,
          apiKey: str(b.apiKey),
        });
      }
    }
    if (balance.length === 0) balance = [{ name: "DeepSeek", type: "deepseek", apiKey: "" }];

    return {
      scale: clamp(num(j.scale, 1), 0.6, 2.5),
      sound: bool(j.sound, true),
      soundSet: j.soundSet === "fx1" ? "fx1" : "duck",
      volume: clamp(num(j.volume, 1), 0, 1),
      model: str(j.model) || "DSniang1.png",
      models,
      edgePad: Math.round(clamp(num(j.edgePad, 3), 0, 24)),
      snapZone: clamp(num(j.snapZone, 0.22), 0.05, 0.5),
      idleTalk: bool(j.idleTalk, true),
      idleTalkMinutes: Math.max(1, num(j.idleTalkMinutes, 5)),
      idleTalkChance: clamp(num(j.idleTalkChance, 0.4), 0, 1),
      bubbleScale: clamp(num(j.bubbleScale, 1.3), 0.8, 2.5),
      screen: str(j.screen),
      balance,
    };
  }

  // 与 shell.qml 的窗口几何保持一致
  function layout(config) {
    const whaleW = Math.round(BASE_W * config.scale);
    const whaleH = whaleW;
    const rawW = (whaleW + config.edgePad * 2) * config.bubbleScale;
    const width = Math.round(rawW);
    const artScale = width / ART_W;
    const artH = ART_H * artScale;
    const whaleTop = Math.max(216, Math.round(ART_H * (rawW / ART_W)) + 16);
    return {
      whaleW, whaleH,
      edgePad: config.edgePad,
      width,
      height: whaleH + whaleTop,
      whaleTop,
      artScale,
      artH,
      artW: ART_W * artScale,
    };
  }

  function isPeak(date) {
    const d = date || new Date();
    const day = d.getDay();
    if (day === 0 || day === 6) return false;
    const h = d.getHours();
    return (h >= 9 && h < 12) || (h >= 14 && h < 18);
  }

  function modelLabel(model) {
    const base = String(model || "").split(/[\\/]/).pop().replace(/\.[^.]+$/, "");
    const names = { DSniang1: "小鲸鱼", xiaoke: "小克", gptniang: "GPT娘" };
    return names[base] || base;
  }

  return {
    BASE_W, ART_W, ART_H,
    BUBBLE_PATH_MAIN, BUBBLE_PATH_DOT1, BUBBLE_PATH_DOT2,
    DEFAULT_MODELS,
    defaultConfig, normalizeConfig, layout, isPeak, modelLabel, clamp,
  };
});
