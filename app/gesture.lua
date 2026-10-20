-- Three-finger horizontal swipe. The overview opens at touch-down; the
-- remaining signed travel scrubs the selected card. Lift commits, cancel aborts.
local function send(value)
  hl.dispatch(hl.dsp.event("window-glide," .. value))
end

local function coordinates(ev, axis)
  if type(ev) ~= "table" then return 0, 0 end
  local delta = ev.delta
  if type(delta) == "table" then
    return tonumber(delta.x or delta[1]) or 0, tonumber(delta.y or delta[2]) or 0
  end
  if type(delta) == "number" then
    if axis == "h" then return delta, 0 end
    return 0, delta
  end
  return 0, 0
end

local function handlers(axis)
  local totalX, totalY = 0, 0
  local function start()
    totalX, totalY = 0, 0
    send(axis .. ":begin")
  end
  local function update(ev)
    local dx, dy = coordinates(ev, axis)
    totalX, totalY = totalX + dx, totalY + dy
    send(axis .. ":move:" .. string.format("%.3f", totalX) .. ":" .. string.format("%.3f", totalY))
  end
  local function finish(ev)
    send(axis .. ":finish:" .. string.format("%.3f", totalX) .. ":" .. string.format("%.3f", totalY) .. ":" ..
      ((type(ev) == "table" and ev.cancelled == true) and "1" or "0"))
    totalX, totalY = 0, 0
  end
  return { start = start, update = update, finish = finish, ["end"] = finish }
end

-- Unset only our own previous registration. Trying to unset a gesture that
-- does not exist reports an error through Hyprland's Lua bridge.
if _G.__window_glide_registered then
  for _, direction in ipairs(_G.__window_glide_directions or { "horizontal", "vertical" }) do
    hl.gesture({ fingers = 3, direction = direction, action = "unset" })
  end
end

hl.gesture({ fingers = 3, direction = "horizontal", action = handlers("h") })
hl.gesture({ fingers = 3, direction = "up", action = function()
  if not hl.get_active_window() then return end
  hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "set", layout_aware = false }))
end })
hl.gesture({ fingers = 3, direction = "down", action = function()
  local window = hl.get_active_window()
  if not window then return end
  if window.fullscreen ~= 0 then
    hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "unset", layout_aware = window.fullscreen_handler ~= "default" }))
  else
    hl.dispatch(hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))
  end
end })
_G.__window_glide_directions = { "horizontal", "up", "down" }
_G.__window_glide_registered = true
