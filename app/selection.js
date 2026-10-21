.pragma library

// Reject empty/transparent and effectively black export frames. A rejected
// frame must never replace a previous usable preview.
function usablePreview(rgba) {
  var lit = 0;
  for (var i = 0; i < rgba.length; i += 4) {
    if (rgba[i + 3] > 16 && Math.max(rgba[i], rgba[i + 1], rgba[i + 2]) > 12) lit++;
  }
  return lit >= Math.max(4, rgba.length / 4 * 0.005);
}

function rectCenters(rects) {
  return rects.map(function (rect) { return { x: rect.cx, y: rect.cy }; });
}

// A larger canvas on portrait screens keeps vertically split windows legible.
function overviewHeight(screenWidth, screenHeight) {
  if (screenWidth <= 0 || screenHeight <= 0) return 0;
  var portrait = Math.max(0, Math.min(1, (screenHeight / screenWidth - 1) / 0.6));
  return Math.min(Math.max(0, screenHeight - 120), screenHeight * (0.48 + 0.22 * portrait));
}

// Preserve each workspace's spatial layout, then place workspaces side by side.
// One common scale preserves relative window sizes across the whole overview.
function overviewStrip(windows, screenWidth, screenHeight, viewportWidth, height) {
  var padding = 16, labelHeight = 28, gap = 48;
  if (!windows.length || screenWidth <= 0 || screenHeight <= 0 || viewportWidth <= 0 || height <= padding * 2 + labelHeight)
    return { rects: [], groups: [], width: Math.max(0, viewportWidth), height: Math.max(0, height) };
  var groups = [];
  windows.forEach(function (win, index) {
    var workspace = win.workspaceId === undefined ? 0 : win.workspaceId;
    var group = groups.find(function (item) { return item.id === workspace; });
    if (!group) {
      group = { id: workspace, name: win.workspaceName || String(workspace), items: [] };
      groups.push(group);
    }
    var valid = [win.sourceX, win.sourceY, win.sourceW, win.sourceH].every(Number.isFinite)
      && win.sourceW > 0 && win.sourceH > 0;
    group.items.push(valid
      ? { index: index, x: win.sourceX * screenWidth, y: win.sourceY * screenHeight,
          w: win.sourceW * screenWidth, h: win.sourceH * screenHeight }
      : { index: index, x: group.items.length * screenWidth * 0.55, y: 0, w: screenWidth * 0.5, h: screenHeight });
  });
  groups.sort(function (a, b) { return a.id - b.id; });
  var tallest = 1, widest = 1;
  groups.forEach(function (group) {
    group.left = Math.min.apply(null, group.items.map(function (r) { return r.x; }));
    group.top = Math.min.apply(null, group.items.map(function (r) { return r.y; }));
    group.w = Math.max.apply(null, group.items.map(function (r) { return r.x + r.w; })) - group.left;
    group.h = Math.max.apply(null, group.items.map(function (r) { return r.y + r.h; })) - group.top;
    tallest = Math.max(tallest, group.h);
    widest = Math.max(widest, Math.max.apply(null, group.items.map(function (r) { return r.w; })));
  });
  var scale = Math.min((height - padding * 2 - labelHeight) / tallest,
    Math.max(1, viewportWidth - padding * 2) * 0.86 / widest);
  var totalWidth = groups.reduce(function (sum, group) { return sum + group.w * scale; }, 0)
    + gap * (groups.length - 1) + padding * 2;
  var contentWidth = Math.max(viewportWidth, totalWidth);
  var cursor = (contentWidth - totalWidth) / 2 + padding;
  var rects = new Array(windows.length);
  var labels = [];
  groups.forEach(function (group) {
    labels.push({ id: group.id, name: group.name, x: cursor, width: group.w * scale });
    group.items.forEach(function (r) {
      var x = cursor + (r.x - group.left) * scale;
      var y = padding + labelHeight + (height - padding * 2 - labelHeight - group.h * scale) / 2 + (r.y - group.top) * scale;
      var w = r.w * scale, h = r.h * scale;
      rects[r.index] = { x: x, y: y, w: w, h: h, cx: x + w / 2, cy: y + h / 2 };
    });
    cursor += group.w * scale + gap;
  });
  return { width: contentWidth, height: height, rects: rects, groups: labels };
}

// Amplify touchpad travel to keep large previews easy to navigate.
function gestureIndex(points, travelX, travelY, width, height) {
  if (!points.length) return -1;
  var gain = 6;
  var x = Math.max(0, Math.min(width, points[0].x + travelX * gain));
  var y = Math.max(0, Math.min(height, points[0].y + travelY * gain));
  return nearestIndex(points, x, y);
}

// Select the thumbnail nearest the virtual pointer, independent of list order.
function nearestIndex(points, x, y) {
  if (!points.length) return -1;
  var nearest = 0;
  var distance = Infinity;
  for (var index = 0; index < points.length; index++) {
    var dx = points[index].x - x;
    var dy = points[index].y - y;
    var candidate = dx * dx + dy * dy;
    if (candidate < distance) {
      distance = candidate;
      nearest = index;
    }
  }
  return nearest;
}

function addressSelector(address) {
  return "address:0x" + String(address).replace(/^0x/i, "");
}

// Stable ordering keeps the focused window first as a fallback.
function orderedWindows(windows, currentWorkspace) {
  return windows.slice().sort(function (a, b) {
    if (!!a.active !== !!b.active) return a.active ? -1 : 1;
    if ((a.workspaceId === currentWorkspace) !== (b.workspaceId === currentWorkspace))
      return a.workspaceId === currentWorkspace ? -1 : 1;
    return String(a.key).localeCompare(String(b.key));
  });
}

// Keep previews across workspace switches, dropping only closed windows.
function livePreviewFrames(frames, clients) {
  var keys = new Set(clients.filter(function (client) { return client.mapped !== false; })
    .map(function (client) { return String(client.address).replace(/^0x/i, ""); }));
  var result = {};
  Object.keys(frames).forEach(function (key) {
    if (keys.has(String(key).replace(/^0x/i, ""))) result[key] = frames[key];
  });
  return result;
}
