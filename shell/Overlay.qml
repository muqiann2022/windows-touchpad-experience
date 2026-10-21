import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Commons as Commons
import Quickshell.Hyprland
import "../app/selection.js" as Selection

Scope {
  id: root
  property var shell: null
  property var manifest: null
  property var service: null

  function findService() {
    if (!service && shell && typeof shell.serviceFor === "function")
      service = shell.serviceFor("muqiann.window-glide")
  }
  onShellChanged: findService()
  Timer { interval: 500; repeat: true; running: !root.service; triggeredOnStart: true; onTriggered: root.findService() }
  function open(payload) { if (service) service.snapshot() }
  function close() { if (service) service.dismiss() }
  function toggle() { if (service) service.showing ? service.dismiss() : root.open({}) }

  function updateSelection(panel) {
    if (!service || !service.showing || !service.windows.length || !panel.visible) return
    const points = Selection.rectCenters(panel.cardRects)
    if (!points.length) return
    const x = Math.max(0, Math.min(panel.stripLayout.width, points[0].x + service.gestureTravelX * 4))
    const y = Math.max(0, Math.min(panel.overviewHeight, points[0].y + service.gestureTravelY * 4))
    service.choose(Selection.nearestIndex(points, x, y))
    panel.revealSelection()
  }

  Variants {
    model: Quickshell.screens
    delegate: PanelWindow {
      id: panel
      required property var modelData
      screen: modelData
      visible: root.service ? root.service.showing &&
        (!Hyprland.focusedMonitor || modelData.name === Hyprland.focusedMonitor.name) : false
      onVisibleChanged: if (visible) { strip.contentX = 0; root.updateSelection(panel) }
      color: "transparent"
      WlrLayershell.namespace: "window-glide"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      exclusionMode: ExclusionMode.Ignore
      anchors { top: true; bottom: true; left: true; right: true }

      readonly property real overviewHeight: Selection.overviewHeight(panel.width, panel.height)
      readonly property var stripLayout: Selection.overviewStrip(root.service ? root.service.windows : [],
        panel.width, panel.height, strip.width, overviewHeight)
      readonly property var cardRects: stripLayout.rects
      onCardRectsChanged: if (visible) root.updateSelection(panel)

      function revealSelection() {
        if (!root.service) return
        const rect = cardRects[root.service.selectedIndex]
        if (!rect) return
        let nextX = strip.contentX
        if (rect.x < nextX + 16) nextX = rect.x - 16
        else if (rect.x + rect.w > nextX + strip.width - 16) nextX = rect.x + rect.w - strip.width + 16
        strip.contentX = Math.max(0, Math.min(strip.contentWidth - strip.width, nextX))
      }

      Rectangle {
        anchors.fill: parent
        color: "#99090b10"
      }

      Flickable {
        id: strip
        anchors.centerIn: parent
        width: Math.max(1, parent.width - Math.min(96, parent.width * 0.08))
        height: panel.overviewHeight
        contentWidth: panel.stripLayout.width
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.horizontal: ScrollBar {
          policy: strip.contentWidth > strip.width ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        }

        Repeater {
          model: panel.stripLayout.groups
          delegate: Text {
            required property var modelData
            x: modelData.x
            y: 8
            width: modelData.width
            text: "桌面 " + modelData.name
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Commons.Color.foreground
            font.pixelSize: 14
          }
        }

        Repeater {
          model: root.service ? root.service.windows : []
          delegate: Item {
            id: card
            required property var modelData
            required property int index
            property bool grabbing: false
            readonly property var rect: panel.cardRects[index] || ({ x: panel.width / 2 - 180, y: panel.height / 2 - 120, w: 360, h: 240 })
            // Toplevel export renders the window independently of workspace visibility.
            readonly property bool canCapture: !!card.modelData.capture
            readonly property var cachedFrame: root.service ? root.service.previewFrames[modelData.key] : null
            x: rect.x
            y: rect.y
            width: rect.w
            height: rect.h
            z: root.service && index === root.service.selectedIndex
              ? root.service.windows.length + 2
              : (card.modelData.active ? root.service.windows.length + 1 : index + 1)

            Rectangle {
              anchors.fill: parent
              radius: 0
              color: "#1c1c22"
              clip: true
              ScreencopyView {
                id: capture
                anchors.fill: parent
                captureSource: root.service && root.service.showing && card.canCapture ? card.modelData.capture : null
                live: true
              }
              Image {
                anchors.fill: parent
                source: card.cachedFrame ? card.cachedFrame.url : ""
                fillMode: Image.Stretch
                visible: !!card.cachedFrame
              }
              // Cover the capture until a sampled frame has passed validation.
              // hasContent also becomes true for compositor-supplied black frames.
              Rectangle { anchors.fill: parent; color: "#1c1c22"; visible: !card.cachedFrame }
              Item {
                anchors.fill: parent
                visible: !card.cachedFrame
                Column {
                  anchors.centerIn: parent
                  width: Math.min(parent.width - 32, 300)
                  spacing: 10
                  Text {
                    width: parent.width
                    text: card.modelData.title
                    textFormat: Text.PlainText
                    color: "#ece9e1"
                    font.pixelSize: 17
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                  }
                  Text {
                    width: parent.width
                    text: "正在获取窗口预览…"
                    color: "#a7a5ae"
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                  }
                }
              }
              Timer {
                interval: 200
                repeat: true
                running: root.service && root.service.showing && card.canCapture && capture.hasContent && !probe.frame && !card.grabbing
                onTriggered: {
                  const key = card.modelData.key
                  const generation = root.service.snapshotGeneration
                  card.grabbing = true
                  const started = capture.grabToImage(function (frame) {
                    if (!card) return
                    card.grabbing = false
                    if (!root.service || !root.service.showing || !card.canCapture
                      || root.service.snapshotGeneration !== generation || card.modelData.key !== key) return
                    probe.frame = frame
                    probe.generation = generation
                    probe.loadImage(frame.url)
                    if (probe.isImageLoaded(frame.url)) probe.validateFrame()
                    else if (probe.isImageError(frame.url)) probe.clearFrame()
                  }, Qt.size(Math.max(1, card.width), Math.max(1, card.height)))
                  if (!started) card.grabbing = false
                }
              }
              Canvas {
                id: probe
                width: 32
                height: 24
                opacity: 0
                property var frame: null
                property int generation: -1
                onImageLoaded: validateFrame()
                function clearFrame() {
                  if (frame) unloadImage(frame.url)
                  frame = null
                }
                function validateFrame() {
                  if (!frame) return
                  const ctx = getContext("2d")
                  ctx.clearRect(0, 0, width, height)
                  ctx.drawImage(frame.url, 0, 0, width, height)
                  const pixels = ctx.getImageData(0, 0, width, height).data
                  if (root.service && root.service.showing && root.service.snapshotGeneration === generation
                    && card.canCapture && Selection.usablePreview(pixels))
                    root.service.cachePreviewFrame(card.modelData.key, frame)
                  clearFrame()
                }
              }
            }
            Rectangle {
              anchors.fill: parent
              // QML paints borders inward; expand so the inner edge meets the preview.
              anchors.margins: -border.width
              radius: 0
              color: "transparent"
              border.width: root.service && index === root.service.selectedIndex ? 4 : 1
              border.color: root.service && index === root.service.selectedIndex ? Commons.Color.accent : Commons.Color.foreground
            }
          }
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: strip.bottom
        anchors.topMargin: 20
        text: "跨桌面滑动选择 · 松开切换 · Esc 取消"
        color: "#d8d5cc"
        font.pixelSize: 16
      }

      Connections {
        target: root.service
        function onGestureTravelXChanged() { root.updateSelection(panel) }
        function onGestureTravelYChanged() { root.updateSelection(panel) }
      }

      Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
          if (event.key === Qt.Key_Escape) { root.service.dismiss(); event.accepted = true }
        }
      }
    }
  }
}
