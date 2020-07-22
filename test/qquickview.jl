using Test
using QML

# absolute path in case working dir is overridden
qml_file = joinpath(dirname(@__FILE__), "qml", "qquickview.qml")

qview = init_qquickview()
ctx = root_context(QML.engine(qview))
set_context_property(ctx, "hi", "Hi from Julia")

# Load QML after setting context properties, to avoid errors
qmlurl = QUrlFromLocalFile(qml_file)
println("Loading QQuickview QML from $(QML.toString(qmlurl))")
set_source(qview, qmlurl)
QML.show(qview)

exec()
