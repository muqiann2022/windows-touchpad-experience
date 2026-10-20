import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";

const context = {};
const source = readFileSync(new URL("../app/selection.js", import.meta.url), "utf8")
  .replace(/^\.pragma library\s*/, "");
vm.runInNewContext(source + "\nthis.api = { overviewStrip, rectCenters, nearestIndex, addressSelector, orderedWindows, usablePreview, livePreviewFrames };", context);
const { overviewStrip, rectCenters, nearestIndex, addressSelector, orderedWindows, usablePreview, livePreviewFrames } = context.api;
const desktop = Array.from({ length: 20 }, (_, i) => ({
  sourceX: i * 0.5, sourceY: 0.03, sourceW: 0.48, sourceH: 0.95,
}));
const strip = overviewStrip(desktop, 1692, 1128, 1596, 376);
assert.equal(strip.height, 376);
assert.ok(strip.width > 1596, "many windows overflow horizontally instead of shrinking further");
assert.ok(strip.rects.every(r => r.y >= 0 && r.y + r.h <= 376), "all windows fit the fixed height");
assert.ok(Math.abs(strip.rects[0].w / strip.rects[0].h - (0.48 * 1692) / (0.95 * 1128)) < 1e-10, "window aspect ratios are preserved");
const shortStrip = overviewStrip(desktop.slice(0, 2), 1692, 1128, 1596, 376);
assert.equal(shortStrip.width, 1596, "a small desktop fits without scrolling");
assert.equal(strip.rects[0].w, shortStrip.rects[0].w, "adding horizontal windows must not change thumbnail height or scale");
assert.ok(nearestIndex(rectCenters(strip.rects), strip.rects[19].cx, strip.rects[19].cy) === 19, "selection can reach beyond the initial viewport");
assert.equal(usablePreview(new Uint8Array(32 * 24 * 4)), false, "transparent frames must not overwrite cached previews");
const blackFrame = new Uint8Array(32 * 24 * 4);
for (let i = 3; i < blackFrame.length; i += 4) blackFrame[i] = 255;
assert.equal(usablePreview(blackFrame), false, "opaque black compositor frames are rejected too");
const darkWindow = blackFrame.slice();
for (let i = 0; i < 20 * 4; i += 4) darkWindow[i] = 200;
assert.equal(usablePreview(darkWindow), true, "dark windows with visible content remain usable");

assert.equal(nearestIndex([], 50, 50), -1);
assert.equal(addressSelector("0xabc"), "address:0xabc");
assert.equal(addressSelector("abc"), "address:0xabc");
assert.equal(addressSelector("0Xabc"), "address:0xabc");
const stacked = overviewStrip([
  { sourceX: -0.5, sourceY: 0, sourceW: 0.48, sourceH: 0.4 },
  { sourceX: -0.5, sourceY: 0.45, sourceW: 0.48, sourceH: 0.55 },
  { sourceX: 0, sourceY: 0, sourceW: 0.48, sourceH: 1 },
], 1692, 1128, 1596, 376);
assert.equal(stacked.rects[0].x, stacked.rects[1].x, "stacked windows stay in one column");
assert.ok(stacked.rects[0].y < stacked.rects[1].y);
assert.ok(stacked.rects[2].x > stacked.rects[0].x, "negative desktop coordinates retain spatial order");
assert.equal(nearestIndex(rectCenters(stacked.rects), stacked.rects[1].cx, stacked.rects[1].cy), 1);
assert.equal(overviewStrip([], 1692, 1128, 1596, 376).rects.length, 0);
assert.equal(overviewStrip([{}], 1692, 1128, 1596, 376).rects.length, 1, "missing geometry has a usable fallback");
assert.equal(overviewStrip(desktop, 0, 0, 0, 0).rects.length, 0, "uninitialized screen dimensions must not produce NaNs");
const frameA = {}, frameB = {};
const retained = livePreviewFrames({ abc: frameA, "0xdef": frameB, dead: {} }, [
  { address: "0xabc", mapped: true, workspace: { id: 1 } },
  { address: "0xdef", mapped: true, workspace: { id: 2 } },
]);
assert.equal(retained.abc, frameA);
assert.equal(retained["0xdef"], frameB, "switching workspaces must not evict another workspace's preview");
assert.equal(retained.dead, undefined, "closed windows release their previews");
assert.equal(livePreviewFrames({ abc: {} }, [{ address: "0xabc", mapped: false }]).abc, undefined);

assert.deepEqual(orderedWindows([
  { key: "b", active: false },
  { key: "z", active: true },
  { key: "a", active: false },
]).map(w => w.key), ["z", "a", "b"]);

console.log("window-glide selection tests passed");
