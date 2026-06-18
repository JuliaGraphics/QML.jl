import QtQuick
import QtQuick.Controls
import Qt.labs.platform

ApplicationWindow {
  visible: true
  width: 320
  height: 240

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.RightButton
    onClicked: zoomMenu.open()
  }

  Menu {
    id: zoomMenu

    MenuItem {
      text: qsTr("Zoom In")
      shortcut: StandardKey.ZoomIn
      onTriggered: zoomIn()
    }

    MenuItem {
      text: qsTr("Zoom Out")
      shortcut: StandardKey.ZoomOut
      onTriggered: zoomOut()
    }
  }

  Timer {
    interval: 1000; running: true; repeat: false
    onTriggered: Qt.exit(0)
  }
}