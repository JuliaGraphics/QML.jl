import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

ApplicationWindow {
  title: "Gradient"
  width: 300
  height: 300
  visible: true

  Item {
      width: 300
      height: 300

      RadialGradient {
          anchors.fill: parent
          gradient: Gradient {
              GradientStop { position: 0.0; color: "yellow" }
              GradientStop { position: 0.5; color: "blue" }
          }
      }
  }

  Timer {
      interval: 500; running: true; repeat: false
      onTriggered: Qt.exit(0)
  }
}
