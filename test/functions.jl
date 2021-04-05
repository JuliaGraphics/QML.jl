using Test
using QML
using CxxWrap

include(joinpath("include","functions_module.jl"))
using .TestModuleFunction

# Test calling Julia functions

call_results1 = []

function julia_callback1(x)
  global call_results1
  push!(call_results1, x)
  nothing
end

call_results2 = []

function julia_callback2(x, y)
  global call_results2
  push!(call_results2, x*y)
  nothing
end

return_callback() = Int32(5)

function check_return_callback(x::Int32)
  @test x == 5
  nothing
end

function test_qvariant_map(m::QVariantMap)
  @test QML.value(m["somekey"]) == "somevalue"
  nothing
end

mutable struct CustomType
  a::Int
  b::String
end

const customglobal = CustomType(1,"One")

function getglobal()
  global customglobal
  return customglobal
end

function settwo(x::CustomType)
  x.a = 2
  x.b = "Two"
end

module UnExported

using Test

return_two() = 2.0

function check(x)
  @test x == 2.0
  return
end

end

set_state2 = TestModuleFunction.set_state2
@qmlfunction julia_callback1 julia_callback2 return_callback check_return_callback test_qvariant_map set_state1 set_state2 getglobal settwo

qmlfunction("unexported_return_two", UnExported.return_two)
qmlfunction("unexported_check", UnExported.check)

loadqml(joinpath(dirname(@__FILE__), "qml", "functions.qml"))
exec()

@test typeof(call_results1[1]) == Bool
@test typeof(call_results1[2]) == Int32
@test typeof(call_results1[3]) == Float64
@test typeof(call_results1[4]) <: QString
@test typeof(call_results1[5]) <: JuliaDisplay
@test call_results1[1:4] == [false, 1, 1.5, "test"]

@test typeof(call_results2[1]) == Float64
@test typeof(call_results2[2]) == Int32
@test typeof(call_results2[3]) == String
@test call_results2 == [3., 6, "ab"]

@test get_state() == 2

@test customglobal.a == 2
@test customglobal.b == "Two"