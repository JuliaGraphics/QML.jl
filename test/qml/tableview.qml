import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.qmlmodels
import jlqml

ApplicationWindow {
  title: "Arrays"
  width: 400
  height: 600
  visible: true

  ColumnLayout{
    spacing: 1
    anchors.centerIn: parent

    RowLayout {
      Layout.alignment: Qt.AlignCenter
      
      ColumnLayout {
        spacing: 1

        Button {
          Layout.alignment: Qt.AlignCenter
          text: "Add row"
          onClicked: {
            tablemodel.appendRow([7,8]);
          }
        }

        Button {
          Layout.alignment: Qt.AlignCenter
          text: "Insert row"
          onClicked: {
            tablemodel.insertRow(2, [9,10]);
          }
        }

        Button {
          Layout.alignment: Qt.AlignCenter
          text: "Set row"
          onClicked: {
            tablemodel.setRow(1, [42,43]);
          }
        }

        Button {
          Layout.alignment: Qt.AlignCenter
          text: "Move row"
          onClicked: {
            tablemodel.moveRow(0,1,2);
          }
        }

        Button {
          Layout.alignment: Qt.AlignCenter
          text: "Remove row"
          onClicked: {
            tablemodel.removeRow(1,2);
          }
        }

        Button {
          Layout.alignment: Qt.AlignCenter
          text: "Add row dict"
          onClicked: {
            tablemodel.appendRow({1: 152, 2: 153});
          }
        }
      }

      ColumnLayout {
        spacing: 1

        Button {
          Layout.alignment: Qt.AlignCenter
          text: "Add column"
          onClicked: {
            tablemodel.appendColumn([7,8,9]);
          }
        }

        Button {
          Layout.alignment: Qt.AlignCenter
          text: "Insert column"
          onClicked: {
            tablemodel.insertColumn(0, [9,10,12]);
          }
        }

        Button {
          Layout.alignment: Qt.AlignCenter
          text: "Set column"
          onClicked: {
            tablemodel.setColumn(1, [42,43,44]);
          }
        }

        Button {
          Layout.alignment: Qt.AlignCenter
          text: "Move column"
          onClicked: {
            tablemodel.moveColumn(0,1,2);
          }
        }

        Button {
          Layout.alignment: Qt.AlignCenter
          text: "Remove column"
          onClicked: {
            tablemodel.removeColumn(0,2);
          }
        }
        
      }
    }

    Item {

      Layout.alignment: Qt.AlignCenter
      Layout.preferredWidth: 300
      Layout.preferredHeight: 200

      HorizontalHeaderView {
        id: horizontalHeader
        syncView: tableView
        anchors.left: tableView.left
      }

      VerticalHeaderView {
        id: verticalHeader
        syncView: tableView
        anchors.top: tableView.top
      }

      TableView {
        id: tableView

        anchors.fill: parent
        anchors.topMargin: horizontalHeader.height
        anchors.leftMargin: verticalHeader.width

        columnSpacing: 1
        rowSpacing: 1
        clip: true

        model: tablemodel

        delegate: Rectangle {
          implicitWidth: 20
          implicitHeight: 15
          Text {
            anchors.centerIn: parent
            text: display
          }
        }
      }
    }
  }

  function getValues(nbrows, nbcols) {
    var result = new Array(nbrows);
    Julia.compare(nbrows, tablemodel.rowCount());
    Julia.compare(nbcols, tablemodel.columnCount());
    for(var row = 0; row < nbrows; row++) {
      result[row] = new Array(nbcols);
      for(var col = 0; col < nbcols; col++) {
        result[row][col] = parseInt(tableView.itemAtCell(col,row).children[0].text);
      }
    }
    return result;
  }

  Timer {
    id: timer
    interval: 250; running: false; repeat: true
    onTriggered: {
      properties.ticks += 1;
      var t = properties.ticks;
      switch(t) {
        case 1:
          Julia.compare(t, getValues(3,2));
          tablemodel.appendRow([7,8]);
          break;
        case 2:
          Julia.compare(t, getValues(4,2));
          tablemodel.insertRow(2, [9,10]);
          break;
        case 3:
          Julia.compare(t, getValues(5,2));
          tablemodel.setRow(1, [42,43]);
          break;
        case 4:
          Julia.compare(t, getValues(5,2));
          tablemodel.moveRow(0,1,2);
          break;
        case 5:
          Julia.compare(t, getValues(5,2));
          tablemodel.removeRow(1,2);
          break;
        case 6:
          Julia.compare(t, getValues(3,2));
          tablemodel.appendRow({1: 152, 2: 153});
          break;
        case 7:
          Julia.compare(t, getValues(4,2));
          tablemodel.appendColumn([7,8,9,10]);
          break;
        case 8:
          Julia.compare(t, getValues(4,3));
          tablemodel.insertColumn(0, [11,12,13,14]);
          break;
        case 9:
          Julia.compare(t, getValues(4,4));
          tablemodel.setColumn(1, [42,43,44,45]);
          break;
        case 10:
          Julia.compare(t, getValues(4,4));
          tablemodel.moveColumn(1,2,2);
          break;
        case 11:
          Julia.compare(t, getValues(4,4));
          tablemodel.removeColumn(2,2);
          break;
        default:
          Julia.compare(t, getValues(4,2));
          timer.running = false;
          Qt.exit(0);
      }
      tableView.forceLayout();
    }
  }

  Component.onCompleted: {
    x = screen.width - width;
    timer.running = true;
  }
}