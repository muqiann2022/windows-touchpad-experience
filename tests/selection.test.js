import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";

const context = {};
const source = readFileSync(new URL("../app/selection.js", import.meta.url), "utf8")
  .replace(/^\.pragma library\s*/, "");
vm.runInNewContext(source + "\nthis.api = { overviewHeight, overviewStrip, rectCenters, nearestIndex, gestureIndex, addressSelector, orderedWindows, usablePreview, livePreviewFrames };", context);
const { overviewHeight, overviewStrip, rectCenters, nearestIndex, gestureIndex, addressSelector, orderedWindows, usablePreview, livePreviewFrames } = context.api;
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
const gesturePoints = [{ x: 500, y: 300 }, { x: 900, y: 300 }, { x: 100, y: 300 }, { x: 500, y: 700 }];
assert.equal(gestureIndex([], 0, 0, 1200, 800), -1);
assert.equal(gestureIndex(gesturePoints, 0, 0, 1200, 800), 0, "touch-down keeps the initial window selected");
assert.equal(gestureIndex(gesturePoints, 33, 0, 1200, 800), 0, "small movements do not immediately switch windows");
assert.equal(gestureIndex(gesturePoints, 34, 0, 1200, 800), 1, "a 400px gap switches after about 33 travel units at gain 6");
assert.equal(gestureIndex(gesturePoints, -34, 0, 1200, 800), 2, "short travel also reaches windows to the left");
assert.equal(gestureIndex(gesturePoints, 0, 34, 1200, 800), 3, "stacked windows use the same reduced travel distance");
assert.equal(gestureIndex(gesturePoints, 10000, 0, 1200, 800), 1, "long travel stays at the edge window");
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


const portraitHeight = overviewHeight(1080, 1920);
assert.ok(portraitHeight > 1920 * 0.6, "portrait previews use enough height for vertical splits");
assert.equal(overviewHeight(1920, 1080), 1080 * 0.48, "landscape overview uses 48 percent of screen height");
assert.equal(overviewHeight(0, 1000), 0);
assert.equal(overviewHeight(1000, 80), 0, "tiny surfaces cannot reserve negative space");
const portraitSplit = overviewStrip([
  { sourceX: 0, sourceY: 0, sourceW: 1, sourceH: 0.5 },
  { sourceX: 0, sourceY: 0.5, sourceW: 1, sourceH: 0.5 },
], 1080, 1920, 984, portraitHeight);
assert.ok(portraitSplit.rects[0].w > 700, "portrait split previews remain comfortably wide");
assert.ok(portraitSplit.rects[0].y + portraitSplit.rects[0].h <= portraitSplit.rects[1].y);
assert.ok(portraitSplit.rects[1].y + portraitSplit.rects[1].h <= portraitHeight - 16);
const grouped = overviewStrip([
  { workspaceId: 2, workspaceName: "Code", sourceX: 0, sourceY: 0, sourceW: 1, sourceH: 1 },
  { workspaceId: 1, sourceX: 0, sourceY: 0, sourceW: 1, sourceH: 1 },
  { workspaceId: 3, sourceX: 0, sourceY: 0, sourceW: 1, sourceH: 1 },
], 1920, 1080, 1824, overviewHeight(1920, 1080));
assert.ok(grouped.rects[1].x + grouped.rects[1].w < grouped.rects[0].x, "other desktops never overlap");
assert.ok(grouped.rects[0].x + grouped.rects[0].w < grouped.rects[2].x);
assert.equal(grouped.groups[1].name, "Code");
assert.equal(nearestIndex(rectCenters(grouped.rects), grouped.rects[1].cx, grouped.rects[1].cy), 1, "can select the workspace to the left");
assert.equal(nearestIndex(rectCenters(grouped.rects), grouped.rects[2].cx, grouped.rects[2].cy), 2, "can select the workspace to the right");
console.log("window-glide selection tests passed");
