using QML

qml_file = joinpath(dirname(@__FILE__), "qml", "repl-background.qml")

@qmlfunction pushdisplay
loadqml(qml_file)
exec_async()

using GR
GR.inline()

# Include from the REPL, and then add plotting commands, e.g:
plot(rand(10,2))
