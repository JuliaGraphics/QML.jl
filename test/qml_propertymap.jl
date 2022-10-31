using Test
using QML
using Observables

let jpm = JuliaPropertyMap()
  @test QML.size(jpm.propertymap) == 0
  @test length(jpm) == 0
  jpm["testkey1"] = 3
  ob = Observable(1)
  jpm["testkey2"] = ob
  @test jpm["testkey1"] == 3
  @test jpm[QString("testkey1")] == 3
  @test jpm["testkey2"] == ob
  @test QML.value(QML.value(jpm.propertymap, "testkey1")) == 3
  @test QML.value(QML.value(jpm.propertymap, "testkey2")) == 1
  println("displaying propertymap")
  display(jpm)
  println()
  ob[] = 2
  @test QML.value(QML.value(jpm.propertymap, "testkey2")) == 2
  @test length(jpm) == 2
  delete!(jpm, "testkey2")
  @test length(jpm) == 1
  @test_throws KeyError jpm["testkey2"]
  @test QML.value(QML.value(jpm.propertymap, "testkey2")) === nothing
  ob[] = 4
  @test ob[] == 4
  @test QML.value(QML.value(jpm.propertymap, "testkey2")) === nothing
end

# absolute path in case working dir is overridden
qml_file = joinpath(dirname(@__FILE__), "qml", "qml_propertymap.qml")

function propertymap_test(b)
  @test b
  return
end

expected_ob = 2

function set_expected_ob(x)
  global expected_ob
  expected_ob = x
  return
end

function do_ob_update(x)
  set_expected_ob(x)
  global ob
  ob[] = x
end

function pass_propertymap(pm::AbstractDict)
  @test pm["a"] == 1
end

@qmlfunction propertymap_test set_expected_ob do_ob_update pass_propertymap

propmap = JuliaPropertyMap()
propmap["a"] = 1
@test propmap["a"] == 1

ob = Observable(expected_ob)
propmap["ob"] = ob

ob_handler_calls = 0

on(ob) do x
  global ob_handler_calls
  ob_handler_calls += 1
  @test x == expected_ob
end

expected_ob = 3
println("setting ob from Julia to value $expected_ob")
ob[] = expected_ob

@test propmap["ob"][] == expected_ob

# Load the QML file, setting the property map as context object
loadqml(qml_file; propmap=propmap)

# Run the application
exec()

@test ob[] == expected_ob
@test ob_handler_calls == 3
@test propmap["a"] == 2