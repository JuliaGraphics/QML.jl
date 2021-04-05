using QML
using Test

qmlfile = joinpath(dirname(@__FILE__), "qml", "badqml.qml")

try
    loadqml(qmlfile)
    exec()
catch e
    @test e.msg == "Failed to load QML file $qmlfile"
end
