using QML
using Test

qmlfile = joinpath(dirname(@__FILE__), "qml", "labsplatform.qml")
loadqml(qmlfile)
exec()
