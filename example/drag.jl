using QML

@qmlfunction println
loadqml(joinpath(dirname(@__FILE__), "qml", "drag.qml"))
exec()
