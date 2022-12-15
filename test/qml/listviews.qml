import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.qmlmodels
import org.julialang

ApplicationWindow {
  title: "Arrays"
  width: 200
  height: 500
  visible: true

  ColumnLayout {
    id: root
    spacing: 6
    anchors.fill: parent

    ListView {
      width: 200
      height: 125
      model: array_model
      delegate: Text { text: string}
    }

    ListView {
      id: decoratedlv
      width: 200
      height: 125
      model: array_model2
      delegate: Text {
        text: decorated
      }
    }

    ListView {
      id: lv
      width: 200
      height: 125
      model: array_model2
      delegate: TextField {
        placeholderText: myrole.toString()
        onTextChanged: myrole = text
      }
    }

    ListView {
      id: tabview
      width: 200
      height: 125
      model: tablemodel

      function setcolumns() {
        if(model.roles.length == 2) {
          delegate = acDelegate
        }
      }

      delegate: Text {
        text: a + "|" + b + "|" + c
      }
    }
  }

  Timer {
    interval: 500; running: true; repeat: false
    onTriggered: {

      decoratedlv.currentIndex = 0
      if(decoratedlv.currentItem.text != "---A---") {
        Julia.testfail("wrong value in decorated list: " + decoratedlv.currentItem.text)
      }

      lv.currentIndex = 0
      lv.currentItem.text = "TEST"

      if(tabview.currentItem.text != "1|2|3") {
        Julia.testfail("bad model text: " + tabview.currentItem.text)
      }

      Julia.setfirstmodelrow()

      if(tabview.currentItem.text != "7|8|9") {
        Julia.testfail("bad model text after change: " + tabview.currentItem.text)
      }

      Qt.exit(0)
    }
  }
}
