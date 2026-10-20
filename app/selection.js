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

// Fit the desktop vertically into a fixed-height strip. Preserve horizontal
// scale even when it exceeds the viewport; the UI scrolls that extra width.
function overviewStrip(windows, screenWidth, screenHeight, viewportWidth, height) {
  var padding = 16;
  if (!windows.length || screenWidth <= 0 || screenHeight <= 0 || viewportWidth <= 0 || height <= padding * 2)
    return { rects: [], width: Math.max(0, viewportWidth), height: Math.max(0, height) };
  var geometry = windows.map(function (win, index) {
    var valid = [win.sourceX, win.sourceY, win.sourceW, win.sourceH].every(Number.isFinite)
      && win.sourceW > 0 && win.sourceH > 0;
    return valid
      ? { x: win.sourceX * screenWidth, y: win.sourceY * screenHeight,
          w: win.sourceW * screenWidth, h: win.sourceH * screenHeight }
      : { x: index * screenWidth * 0.55, y: 0, w: screenWidth * 0.5, h: screenHeight };
  });
  var left = Math.min.apply(null, geometry.map(function (r) { return r.x; }));
  var top = Math.min.apply(null, geometry.map(function (r) { return r.y; }));
  var right = Math.max.apply(null, geometry.map(function (r) { return r.x + r.w; }));
  var bottom = Math.max.apply(null, geometry.map(function (r) { return r.y + r.h; }));
  var scale = Math.max(1, height - padding * 2) / (bottom - top);
  var contentWidth = Math.max(viewportWidth, (right - left) * scale + padding * 2);
  var offsetX = (contentWidth - (right - left) * scale) / 2;
  return { width: contentWidth, height: height, rects: geometry.map(function (r) {
    var x = offsetX + (r.x - left) * scale;
    var y = padding + (r.y - top) * scale;
    var w = r.w * scale;
    var h = r.h * scale;
    return { x: x, y: y, w: w, h: h, cx: x + w / 2, cy: y + h / 2 };
  }) };
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
function orderedWindows(windows) {
  return windows.slice().sort(function (a, b) {
    if (!!a.active !== !!b.active) return a.active ? -1 : 1;
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
