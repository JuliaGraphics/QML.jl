import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.julialang

Item {

  function verify_array(a) {
    if(a[0] != "A" || a[1] != 1 || a[2] != 2.2)
    {
      console.log("Bad array: ", a)
      throw "Error verifying array"
    }
  }

  Timer {
    interval: 200; running: true; repeat: false
    onTriggered: {
      var a = Julia.get_array();
      verify_array(a);
      verify_array(arrays.julia_array);

      if(arrays.int_array[0] != 1 || arrays.int_array[1] != 2 || arrays.int_array[2] != 3) {
        console.log("Bad int array: ", arrays.int_array);
        throw "Error verifying int array";
      }

      arrays.ob_array = [7,8,9];

      array_model2.setData(array_model2.index(2, 0), "TEST2", roles.myrole);
      array_model2.appendRow({"myrole":"Added"});
      array_model2.appendRow({"myrole":2});
      array_model2.appendRow({"myrole":2});
      array_model2.setData(array_model2.index(5, 0), 3, roles.myrole);

      array_model2.removeRow(1);

      move_model.moveRow(2,5,3);

      resize_typed_model.removeRow(2);
      resize_typed_model.moveRow(3,0,1);

      insert_model.insertRow(2,[3]);

      clear_model.clear();

      custom_model.setData(custom_model.index(1,0), 5, roles.b);
      custom_model.appendRow({"b":10, "a":"ten"});

      Qt.quit()
    }
  }
}
