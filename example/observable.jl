using QML
using Observables

qml_file = joinpath(dirname(@__FILE__), "qml", "observable.qml")

const input = Observable(1.0)
const output = Observable(0.0)

on(output) do x
  println("Output changed to ", x)
end

loadqml(qml_file, observables = JuliaPropertyMap("input" => input, "output" => output))

if isinteractive()
  exec_async()
else
  exec()
end