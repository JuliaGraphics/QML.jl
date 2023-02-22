using Test
using QML

# Test use of QTimer

bg_counter = 0

function counter_slot()
  global bg_counter
  bg_counter += 1
end

@qmlfunction counter_slot

qmlfile = joinpath(dirname(@__FILE__), "qml", "qtimer.qml")
loadqml(qmlfile, timer=QTimer())
GC.gc()
exec()

@test bg_counter > 100
