using QML
using Qt65Compat_jll

qml_file = joinpath(dirname(@__FILE__), "qml", "qt5compat.qml")
loadqml(qml_file)
exec()
