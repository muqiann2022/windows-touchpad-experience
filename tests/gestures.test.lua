local gestures, fourFinger, dispatched, active, special = {}, {}, {}, nil, nil
local function dispatcher(kind)
  return function(args) return { kind = kind, args = args } end
end
local env = setmetatable({
  _G = { __window_glide_registered = true },
  hl = {
    gesture = function(spec)
      local registry = spec.fingers == 4 and fourFinger or gestures
      registry[spec.direction] = spec.action
    end,
    get_active_special_workspace = function() return special end,
    get_active_window = function() return active end,
    dispatch = function(action) table.insert(dispatched, action) end,
    dsp = { workspace = { toggle_special = dispatcher("special") }, event = dispatcher("event"), window = { fullscreen = dispatcher("fullscreen"), move = dispatcher("move") } },
  },
}, { __index = _G })
assert(loadfile("app/gesture.lua", "t", env))()
assert(gestures.vertical == "unset", "remove the old vertical overview gesture")
assert(type(gestures.horizontal) == "table", "horizontal overview remains registered")
gestures.up()
gestures.down()
assert(#dispatched == 0, "empty desktops must not trigger window actions")
active = { fullscreen = 0, fullscreen_handler = "scrolling" }
gestures.up()
gestures.up()
assert(dispatched[1].args.action == "set" and dispatched[2].args.action == "set", "repeated up must never toggle maximization off")
assert(dispatched[1].args.mode == "maximized" and dispatched[2].args.mode == "maximized", "up maximizes windows without requesting application fullscreen")
assert(dispatched[1].args.layout_aware == false, "maximize across the working area on scrolling layouts")
active = { fullscreen = 1, fullscreen_handler = "default" }
gestures.down()
assert(dispatched[3].kind == "fullscreen" and dispatched[3].args.action == "unset" and dispatched[3].args.mode == "maximized", "first down restores maximized windows without stashing")
assert(dispatched[3].args.layout_aware == false, "restore maximization with the same default handler")
active = { fullscreen = 0, fullscreen_handler = "scrolling" }
gestures.down()
assert(dispatched[4].kind == "move" and dispatched[4].args.workspace == "special:scratchpad", "down on a restored window stashes it")
assert(dispatched[4].args.follow == false, "stashing must not open the scratchpad")
gestures.horizontal.start()
gestures.horizontal.update({ delta = { x = 12, y = -3 } })
gestures.horizontal.update({ delta = 4 })
gestures.horizontal["end"]({ cancelled = true })
assert(dispatched[5].args == "window-glide,h:begin")
assert(dispatched[7].args == "window-glide,h:move:16.000:-3.000", "accumulate signed 2D travel")
assert(dispatched[8].args == "window-glide,h:finish:16.000:-3.000:1", "cancellation reaches the service")
gestures.horizontal.start()
gestures.horizontal["end"]({ cancelled = false })
assert(dispatched[10].args == "window-glide,h:finish:0.000:0.000:0", "a new gesture resets travel")
assert(loadfile("app/gesture.lua", "t", env))()
assert(type(gestures.up) == "function" and type(gestures.down) == "function", "registration is repeatable after reload")
local before = #dispatched
fourFinger.down()
assert(#dispatched == before, "down outside the scratchpad must do nothing")
fourFinger.up()
assert(dispatched[#dispatched].kind == "special" and dispatched[#dispatched].args == "scratchpad", "up opens the scratchpad")
special = { name = "special:scratchpad" }
before = #dispatched
fourFinger.up()
assert(#dispatched == before, "repeated up keeps the scratchpad open")
fourFinger.down()
assert(#dispatched == before + 1 and dispatched[#dispatched].args == "scratchpad", "down closes the scratchpad")
special = { name = "special:other" }
before = #dispatched
fourFinger.down()
assert(#dispatched == before, "down must not close an unrelated special workspace")
assert(loadfile("app/gesture.lua", "t", env))()
assert(type(fourFinger.up) == "function" and type(fourFinger.down) == "function", "four-finger registration survives reload")
assert(fourFinger.horizontal == nil, "four-finger workspace swipes remain untouched")
for _, handler in ipairs({ "default", "scrolling" }) do
  active = { fullscreen = 2, fullscreen_handler = handler }
  gestures.down()
  local restored = dispatched[#dispatched]
  assert(restored.kind == "fullscreen" and restored.args.mode == "fullscreen" and restored.args.action == "unset", "down still restores existing fullscreen windows")
  assert(restored.args.layout_aware == (handler ~= "default"), "restore uses the window's fullscreen handler")
  gestures.up()
  assert(dispatched[#dispatched].args.mode == "maximized", "up requests maximization even from an existing fullscreen state")
end
active = { fullscreen = 1, fullscreen_handler = "default" }
gestures.up()
assert(dispatched[#dispatched].args.mode == "maximized" and dispatched[#dispatched].args.action == "set", "up on a maximized window keeps it maximized")
print("window-glide gesture tests passed")
