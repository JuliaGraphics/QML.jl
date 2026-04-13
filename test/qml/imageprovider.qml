import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
  visible: true
  width: 320
  height: 240

  RowLayout {
    anchors.fill: parent
    ColumnLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Image {
        source: "image://images/yellow"
        Layout.fillWidth: true
        Layout.fillHeight: true
        sourceSize.width: width
        sourceSize.height: height
      }
      Image { 
        source: "image://images/red"
        Layout.fillWidth: true
        Layout.fillHeight: true
        sourceSize.width: width
        sourceSize.height: height
      }
    }
    Image {
      source: "image://pixmaps/black"
      Layout.fillWidth: true
      Layout.fillHeight: true
      sourceSize.width: width
      sourceSize.height: height
    }
    Image { 
      source: "image://images/yellow"
      Layout.fillWidth: true
      Layout.fillHeight: true
      sourceSize.width: width
      sourceSize.height: height
    }
    Image { 
      source: "image://images/red"
      Layout.fillWidth: true
      Layout.fillHeight: true
      sourceSize.width: width
      sourceSize.height: height
    }
  }

  Timer {
    interval: 1000; running: true; repeat: false
    onTriggered: Qt.exit(0)
  }

}