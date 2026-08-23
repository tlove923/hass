import QtQuick
import Quickshell.Io
import qs.Commons

// A live camera snapshot tile for the Home Assistant panel.
//
// QML Image cannot be relied on to fetch over HTTP in this shell, so the tile
// curls HA's signed camera_proxy URL (short-lived token embedded) to a local
// file and shows that, refreshing on a timer. The bridge token never reaches
// the UI — the signed URL is self-sufficient.
Item {
  id: root

  property string entityId: ""
  property string pictureUrl: ""     // signed HA camera_proxy URL
  property string label: ""
  property int refreshMs: 3000
  property string fontFamily: Style.font.family
  property color foreground: Color.foreground
  property real radius: Style.space(6)

  readonly property string cachePath: "/tmp/hass-cam-" + root.entityId + ".jpg"

  // The delegate sets `width`; the frame height and the total height derive
  // from it (implicitWidth is never set, so a 16:9 frame must not use it).
  readonly property real frameHeight: root.width * 9 / 16
  implicitHeight: root.frameHeight + Style.space(24)

  function fetch() {
    if (root.pictureUrl === "" || fetchProc.running) return
    fetchProc.command = ["curl", "-s", "--max-time", "10",
                         "-o", root.cachePath, root.pictureUrl]
    fetchProc.running = true
  }

  property Process fetchProc: Process {
    onExited: {
      // The path is stable, so toggle the source to force a re-read.
      img.source = ""
      img.source = "file://" + root.cachePath
    }
  }

  Timer {
    interval: root.refreshMs
    running: root.pictureUrl !== ""
    repeat: true
    triggeredOnStart: true
    onTriggered: root.fetch()
  }

  Rectangle {
    id: frame
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: root.frameHeight
    radius: root.radius
    color: Qt.rgba(0, 0, 0, 0.4)
    clip: true

    Image {
      id: img
      anchors.fill: parent
      source: "file://" + root.cachePath
      fillMode: Image.PreserveAspectCrop
      cache: false
      smooth: true
      asynchronous: true
    }

    // Placeholder while no frame has been captured yet.
    Rectangle {
      visible: img.status !== Image.Ready
      anchors.fill: parent
      color: "transparent"
      border.width: 1
      border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15)
      Text {
        anchors.centerIn: parent
        text: img.status === Image.Loading ? "…" : "…"
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.5)
      }
    }
  }

  Text {
    id: nameText
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: frame.bottom
    height: Style.space(24)
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    text: root.label
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    color: root.foreground
  }
}
