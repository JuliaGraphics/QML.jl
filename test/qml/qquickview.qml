import QtQuick

Rectangle {
  width: 100; height: 100; color: "red"

  Text {
    anchors.centerIn: parent
    text: hi // Context property set from Julia
  }

  Timer {
    interval: 500; running: true; repeat: false
    onTriggered: parent.Window.window.close()
  }
}
