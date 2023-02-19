using Test
using QML

# absolute path in case working dir is overridden
qml_data = QByteArray("""
import QtQuick
import QtQuick.Controls

ApplicationWindow {
  id: mainWin
  title: "My Application"
  width: 100
  height: 100
  visible: true

  Rectangle {
    width: 100; height: 100; color: "red"

    Text {
      anchors.centerIn: parent
      text: hi // Context property set from Julia
    }

    Timer {
      interval: 500; running: true; repeat: false
      onTriggered: mainWin.close()
    }
  }
}
""")

qengine = init_qmlengine()
ctx = root_context(qengine)
set_context_property(ctx, "hi", "Hi from Julia")

qcomp = QQmlComponent(qengine)
set_data(qcomp, qml_data, QML.QUrl())
create(qcomp, qmlcontext());

exec()
