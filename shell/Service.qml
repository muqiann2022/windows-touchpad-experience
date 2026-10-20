import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../app/selection.js" as Selection

Scope {
  id: service
  property var shell: null
  property var manifest: null
  property bool showing: false
  property var windows: []
  property var previewFrames: ({})
  property bool awaitingSnapshot: false
  property int snapshotGeneration: 0
  property int snapshotWorkspace: -1
  property string snapshotMonitor: ""
  property int selectedIndex: 0
  property string pendingFocusSelector: ""
  property string gestureAxis: ""
  property real gestureTravelX: 0
  property real gestureTravelY: 0
  readonly property string gestureFile: {
    const url = Qt.resolvedUrl("../app/gesture.lua").toString()
    return url.startsWith("file://") ? decodeURIComponent(url.slice(7)) : url
  }

  function snapshot() {
    cancelPendingFocus()
    service.showing = false
    service.snapshotGeneration++
    service.snapshotWorkspace = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    service.snapshotMonitor = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    service.awaitingSnapshot = true
    startSnapshotQuery()
  }

  function startSnapshotQuery() {
    if (!service.awaitingSnapshot || clientsQuery.running) return
    clientsQuery.generation = service.snapshotGeneration
    snapshotTimeout.restart()
    clientsQuery.running = true
  }

  function acceptSnapshot(clients) {
    if (!service.awaitingSnapshot) return
    service.awaitingSnapshot = false
    snapshotTimeout.stop()
    const workspace = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    const monitor = Hyprland.focusedMonitor || null
    const monitorName = monitor ? monitor.name : ""
    if (workspace !== service.snapshotWorkspace || monitorName !== service.snapshotMonitor) return service.dismiss()
    const monitorIpc = monitor ? monitor.lastIpcObject : {}
    const monitorScale = monitorIpc.scale || 1
    const rotated = monitorIpc.transform % 2 === 1
    const monitorWidth = (rotated ? monitorIpc.height : monitorIpc.width) / monitorScale
    const monitorHeight = (rotated ? monitorIpc.width : monitorIpc.height) / monitorScale
    const rows = []
    for (const top of (Hyprland.toplevels.values || [])) {
      if (!top.wayland || !top.workspace || top.workspace.id !== workspace) continue
      if (!top.monitor || top.monitor.name !== monitorName) continue
      const ipc = clients.find(client => String(client.address).replace(/^0x/, "") === String(top.address).replace(/^0x/, ""))
      if (!ipc || ipc.mapped === false || ipc.hidden || !ipc.workspace || ipc.workspace.id !== workspace) continue
      const at = ipc.at || [0, 0]
      const size = ipc.size || [0, 0]
      rows.push({
        key: String(top.address),
        capture: top.wayland,
        title: String(top.title || top.class || "Window"),
        active: top.activated === true,
        sourceX: monitorWidth > 0 ? (at[0] - monitorIpc.x) / monitorWidth : NaN,
        sourceY: monitorHeight > 0 ? (at[1] - monitorIpc.y) / monitorHeight : NaN,
        sourceW: monitorWidth > 0 ? size[0] / monitorWidth : NaN,
        sourceH: monitorHeight > 0 ? size[1] / monitorHeight : NaN,
      })
    }
    service.previewFrames = Selection.livePreviewFrames(service.previewFrames, clients)
    service.windows = Selection.orderedWindows(rows)
    service.selectedIndex = 0
    service.showing = rows.length > 0
  }

  Process {
    id: clientsQuery
    property int generation: -1
    command: ["hyprctl", "-j", "clients"]
    onRunningChanged: if (!running) nextQuery.restart()
    stdout: StdioCollector {
      onStreamFinished: {
        if (clientsQuery.generation !== service.snapshotGeneration) return
        try { service.acceptSnapshot(JSON.parse(text)) }
        catch (error) { console.warn("Window Glide snapshot failed:", error); service.dismiss() }
      }
    }
  }

  Timer {
    id: nextQuery
    interval: 1
    onTriggered: {
      if (!service.awaitingSnapshot) return
      if (clientsQuery.generation !== service.snapshotGeneration) service.startSnapshotQuery()
      else service.dismiss() // Process exited without a usable response.
    }
  }

  Timer {
    id: snapshotTimeout
    interval: 1500
    onTriggered: {
      clientsQuery.signal(9)
      service.dismiss()
    }
  }

  function registerGestures() {
    const path = gestureFile.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n").replace(/\r/g, "\\r")
    Quickshell.execDetached(["/usr/bin/hyprctl", "eval", 'dofile("' + path + '")'])
  }

  function onGesture(payload) {
    const fields = payload.split(":")
    if (fields.length < 2 || fields[0] !== "h") return
    const axis = fields[0]
    const phase = fields[1]
    if (phase === "begin") {
      service.snapshot()
      service.gestureAxis = axis
      service.gestureTravelX = 0
      service.gestureTravelY = 0
    } else if (axis !== service.gestureAxis) {
      return
    } else if (phase === "move") {
      service.gestureTravelX = Number(fields[2]) || 0
      service.gestureTravelY = Number(fields[3]) || 0
    } else if (phase === "finish") {
      service.gestureTravelX = Number(fields[2]) || 0
      service.gestureTravelY = Number(fields[3]) || 0
      const cancelled = fields[4] === "1"
      if (!cancelled) service.commit()
      else service.dismiss()
      service.gestureAxis = ""
    }
  }

  function commit() {
    if (!service.showing || service.awaitingSnapshot) return service.dismiss()
    if (service.windows.length === 0) return service.dismiss()
    const win = service.windows[service.selectedIndex]
    if (win) service.pendingFocusSelector = Selection.addressSelector(win.key)
    service.dismiss()
    if (service.pendingFocusSelector) focusAfterDismiss.restart()
  }

  function dismiss() {
    service.snapshotGeneration++
    snapshotTimeout.stop()
    service.awaitingSnapshot = false
    service.showing = false
    service.gestureAxis = ""
  }

  function cancelPendingFocus() {
    focusAfterDismiss.stop()
    service.pendingFocusSelector = ""
  }

  function choose(index) {
    if (index >= 0 && index < service.windows.length) service.selectedIndex = index
  }

  function cachePreviewFrame(key, frame) {
    if (!frame || !service.showing || !service.windows.some(win => win.key === key)) return
    const frames = Object.assign({}, service.previewFrames)
    frames[key] = frame
    service.previewFrames = frames
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "custom" && String(event.data || "").startsWith("window-glide,"))
        service.onGesture(String(event.data).slice(13))
      if (event.name === "configreloaded") rearm.restart()
      if (["workspace", "workspacev2", "focusedmon", "closewindow", "monitorremoved"].includes(event.name)) {
        // A captured workspace must not commit after its context changes.
        service.cancelPendingFocus()
        service.dismiss()
        if (event.name === "closewindow") {
          const key = String(event.data || "").replace(/^0x/i, "")
          const frames = Object.assign({}, service.previewFrames)
          for (const cachedKey of Object.keys(frames))
            if (cachedKey.replace(/^0x/i, "") === key) delete frames[cachedKey]
          service.previewFrames = frames
        }
      }
    }
  }

  Timer {
    id: rearm
    interval: 500
    onTriggered: service.registerGestures()
  }

  Timer {
    id: focusAfterDismiss
    interval: 100
    repeat: false
    onTriggered: {
      const selector = service.pendingFocusSelector
      service.pendingFocusSelector = ""
      if (!selector) return
      if (!(Hyprland.toplevels.values || []).some(win => Selection.addressSelector(win.address) === selector)) return
      Hyprland.dispatch('hl.dsp.focus({ window = "' + selector + '" })')
    }
  }

  Component.onCompleted: service.registerGestures()
}
