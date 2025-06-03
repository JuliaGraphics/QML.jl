import QtQuick
import jlqml

Timer {
     interval: 200; running: true; repeat: false
     onTriggered: {
        Julia.pass_propertymap(propmap)
        Julia.propertymap_test(propmap.a == 1)
        Julia.propertymap_test(propmap.ob == 3)

        Julia.set_expected_ob(5)
        console.log("Setting Observable from QML to 5")
        propmap.ob = 5;
        Julia.propertymap_test(propmap.ob == 5)

        console.log("Requesting update from Julia for value 4")
        Julia.do_ob_update(4)
        Julia.propertymap_test(propmap.ob == 4)

        propmap.a = 2

        Qt.exit(0);
     }
 }
