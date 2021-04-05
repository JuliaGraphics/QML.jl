using Test
using QML
using Observables

mutable struct InnerType
  x::Float64
end

# example type
mutable struct JuliaTestType
  a::Int32
  i::InnerType
end

function modify_julia_object(jo::JuliaTestType)
  jo.a = 3
  jo.i.x = 2.0
  return
end

replace_julia_object() = JuliaTestType(1, InnerType(2.0))

geta(jo) = jo.a
getx(jo) = jo.i.x

function julia_object_check(b::Bool)
  @test b
end

logged_x = 0.0

function logx(x)
  global logged_x
  logged_x = x
  return
end

# absolute path in case working dir is overridden
qml_file = joinpath(dirname(@__FILE__), "qml", "julia_object.qml")
observed_object = Observable(JuliaTestType(0,InnerType(0.0)))
@qmlfunction modify_julia_object replace_julia_object julia_object_check geta getx logx

loadqml(qml_file, objects=JuliaPropertyMap("julia_object" => JuliaTestType(1, InnerType(2.0)), "observed_object" => observed_object))

# Run the application
exec()

@test observed_object[].a == 1
@test observed_object[].i.x == 2.0
@test logged_x == 2.0