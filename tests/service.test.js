import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";

// Exercise the service's actual JavaScript methods without requiring a running
// compositor. Timers and the IPC process are controlled by the test.
const selection = readFileSync(new URL("../app/selection.js", import.meta.url), "utf8")
  .replace(/^\.pragma library\s*/, "");
const qml = readFileSync(new URL("../shell/Service.qml", import.meta.url), "utf8");
const methods = [...qml.matchAll(/^  function \w+\([^\n]*\) \{[\s\S]*?^  }/gm)]
  .map(match => match[0]).join("\n");
const timer = () => ({ active: false, stop() { this.active = false; }, restart() { this.active = true; } });
const service = {
  showing: false, awaitingSnapshot: false, snapshotGeneration: 0,
  snapshotWorkspace: -1, snapshotMonitor: "", windows: [], previewFrames: {},
  gestureAxis: "", gestureTravelX: 0, gestureTravelY: 0, pendingFocusSelector: "",
};
const monitor = { name: "test", lastIpcObject: { x: 0, y: 0, width: 2000, height: 1200, scale: 2, transform: 0 } };
const top = { address: "abc", title: "Test", activated: true, wayland: {}, workspace: { id: 1 }, monitor,
  lastIpcObject: { at: [1500, 0] } }; // Deliberately stale coordinates.
const Hyprland = { focusedWorkspace: { id: 1 }, focusedMonitor: monitor, toplevels: { values: [top] } };
const clientsQuery = { running: false, generation: -1 };
const focusAfterDismiss = timer();
const context = vm.createContext({ service, Hyprland, clientsQuery, focusAfterDismiss, snapshotTimeout: timer() });
vm.runInContext(selection + "\nthis.Selection = { livePreviewFrames, orderedWindows, addressSelector };\n" + methods, context);
for (const name of [...methods.matchAll(/function (\w+)\(/g)].map(match => match[1])) service[name] = context[name];
const clients = [{ address: "0xabc", mapped: true, workspace: { id: 1 }, at: [100, 20], size: [400, 500] }];

service.onGesture("v:begin");
assert.equal(service.awaitingSnapshot, false, "vertical gestures must not open the overview");
service.onGesture("h:begin");
service.onGesture("h:finish:0:0:1");
service.acceptSnapshot(clients);
assert.equal(service.showing, false, "a late IPC reply must not reopen a cancelled overview");

clientsQuery.running = false;
service.onGesture("h:begin");
const firstRequest = clientsQuery.generation;
service.onGesture("h:begin");
assert.notEqual(clientsQuery.generation, service.snapshotGeneration, "a second begin invalidates the outstanding query");
assert.equal(clientsQuery.generation, firstRequest);
clientsQuery.running = false;
service.startSnapshotQuery();
assert.equal(clientsQuery.generation, service.snapshotGeneration, "the queued request uses a new generation");
service.acceptSnapshot(clients);
assert.equal(service.showing, true);
assert.equal(service.windows[0].sourceX, 0.1, "use returned coordinates and logical monitor size, never stale toplevel geometry");

service.commit();
assert.equal(service.pendingFocusSelector, "address:0xabc");
assert.equal(focusAfterDismiss.active, true);
clientsQuery.running = false;
service.snapshot();
assert.equal(service.pendingFocusSelector, "", "a new gesture cancels delayed focus from the previous one");
assert.equal(focusAfterDismiss.active, false);
service.commit();
assert.equal(service.pendingFocusSelector, "", "finishing before the snapshot must not focus an old window");

clientsQuery.running = false;
service.onGesture("h:begin");
Hyprland.focusedWorkspace = { id: 2 };
service.acceptSnapshot(clients);
assert.equal(service.showing, false);
assert.equal(service.gestureAxis, "", "a workspace change cancels the gesture before it can commit");

Hyprland.focusedWorkspace = { id: 1 };
clientsQuery.running = false;
service.snapshot();
service.acceptSnapshot([{ ...clients[0], hidden: true }]);
assert.equal(service.windows.length, 0, "hidden/swallowed windows are excluded");
assert.equal(service.showing, false);
service.cachePreviewFrame("abc", {});
assert.equal(service.previewFrames.abc, undefined, "late captures cannot refill a dismissed overview's cache");

clientsQuery.running = false;
const other = { ...top, address: "def", activated: false, workspace: { id: 2 } };
const stash = { ...top, address: "stash", activated: false, workspace: { id: -99 } };
const remote = { ...top, address: "remote", monitor: { name: "other" } };
Hyprland.toplevels.values = [top, other, stash, remote];
service.snapshot();
service.acceptSnapshot([
  clients[0],
  { ...clients[0], address: "0xdef", workspace: { id: 2, name: "Code" } },
  { ...clients[0], address: "0xstash", workspace: { id: -99 } },
  { ...clients[0], address: "0xremote" },
]);
assert.equal(service.windows.length, 2, "include other regular desktops on this monitor, excluding special workspaces and other monitors");
assert.equal(service.windows[1].capture, other.wayland, "inactive desktops retain a toplevel source for direct capture");
assert.equal(service.windows[1].workspaceName, "Code");
service.choose(1);
service.commit();
assert.equal(service.pendingFocusSelector, "address:0xdef", "cross-desktop selection commits the selected window address");
assert.equal(focusAfterDismiss.active, true);
console.log("window-glide service tests passed");
