import QtQuick
import QtTest

TestCase {
  id: testCase
  name: "WindowTitle"
  width: 400
  height: 300

  property string titleSource: ""

  function initTestCase() {
    const request = new XMLHttpRequest()
    request.open("GET", Qt.resolvedUrl("../shell/Overlay.qml"), false)
    request.send()
    // Instantiate the production title field, including its formatting policy.
    const match = request.responseText.match(/Text\s*\{[^{}]*text:\s*card\.modelData\.title\b[^{}]*\}/)
    verify(match !== null, "Production window title field must exist")
    titleSource = match[0]
  }

  function test_plainTitle_data() {
    return [
      { tag: "image", title: '<img src="http://127.0.0.1:9/title-probe.png">' },
      { tag: "rich-text", title: "<b>Window</b> &amp; <i>title</i>" },
      { tag: "ordinary", title: "Terminal — 窗口 & notes <draft>" }
    ]
  }

  function test_plainTitle(data) {
    const card = Qt.createQmlObject('import QtQuick; Item { width: 400; height: 300; property var modelData: ({title: ""}) }', testCase)
    card.modelData = { title: data.title }
    const title = Qt.createQmlObject('import QtQuick; ' + titleSource.replace(/card\.modelData/g, 'parent.modelData'), card)
    compare(title.textFormat, Text.PlainText, "Application metadata must never select a markup parser")
    compare(title.text, data.title, "Titles must remain unchanged")
    const control = Qt.createQmlObject('import QtQuick; Text { textFormat: Text.PlainText }', card)
    control.text = data.title
    control.font = title.font
    control.width = title.width
    control.wrapMode = title.wrapMode
    control.maximumLineCount = title.maximumLineCount
    control.elide = title.elide
    compare(title.contentWidth, control.contentWidth)
    compare(title.contentHeight, control.contentHeight)
    card.destroy()
  }
}
