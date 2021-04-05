using Test
using QML

# Test context properties

propmap = JuliaPropertyMap()
propmap["my_prop"] = 1
propmap["π"] = π

function check_property(x)
  @test x == propmap["my_prop"]
  nothing
end

function check_pi(pi_constant_match)
  @test pi_constant_match
  nothing
end

@qmlfunction check_property check_pi
qmlfile = joinpath(dirname(@__FILE__), "qml", "properties.qml")

loadqml(qmlfile, properties=propmap)
exec()
