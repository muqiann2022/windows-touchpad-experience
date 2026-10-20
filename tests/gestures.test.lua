local gestures, dispatched, active = {}, {}, nil
local function dispatcher(kind)
  return function(args) return { kind = kind, args = args } end
end
local env = setmetatable({
  _G = { __window_glide_registered = true },
  hl = {
    gesture = function(spec) gestures[spec.direction] = spec.action end,
    get_active_window = function() return active end,
    dispatch = function(action) table.insert(dispatched, action) end,
    dsp = { event = dispatcher("event"), window = { fullscreen = dispatcher("fullscreen"), move = dispatcher("move") } },
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
assert(dispatched[1].args.action == "set" and dispatched[2].args.action == "set", "repeated up must never toggle fullscreen off")
assert(dispatched[1].args.layout_aware == false, "use whole-screen fullscreen on scrolling layouts")
active = { fullscreen = 2, fullscreen_handler = "default" }
gestures.down()
assert(dispatched[3].kind == "fullscreen" and dispatched[3].args.action == "unset", "first down restores fullscreen without stashing")
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
print("window-glide gesture tests passed")
