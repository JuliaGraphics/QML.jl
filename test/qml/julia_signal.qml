import QtQuick
import org.julialang

Item {

  JuliaSignals {
    signal testsignal()
    signal testsignalargs(var x, var s)

    onTestsignal: Julia.check1(true)
    onTestsignalargs: function(x,s) { Julia.check2(x,s); }
  }

  Timer {
       interval: 200; running: true; repeat: false
       onTriggered: {
         Julia.emit_signal1()
         Julia.emit_signal2()
         Qt.exit(0)
       }
   }
}
