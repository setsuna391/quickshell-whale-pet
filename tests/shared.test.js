const test = require("node:test");
const assert = require("node:assert/strict");
const shared = require("../windows/shared");

test("config normalization clamps values and handles invalid input", () => {
  const cfg = shared.normalizeConfig({ scale: 99, volume: -1, models: [], idleTalkChance: 2 });
  assert.equal(cfg.scale, 2.5);
  assert.equal(cfg.volume, 0);
  assert.equal(cfg.idleTalkChance, 1);
  assert.deepEqual(cfg.models, shared.DEFAULT_MODELS);
  assert.deepEqual(shared.normalizeConfig(null), shared.defaultConfig());
});

test("layout tracks normalized scale and padding", () => {
  const cfg = shared.normalizeConfig({ scale: 2, edgePad: 4, bubbleScale: 1 });
  const layout = shared.layout(cfg);
  assert.equal(layout.whaleW, 340);
  assert.equal(layout.width, 348);
  assert.ok(layout.height >= layout.whaleH + layout.artH);
});
