using CxxWrap
using QML
using Test

let key = "__QML_TESTVAR", val = "TestStr"
  qputenv(key, QByteArray(val))
  @test ENV[key] == val
  @test QML.to_string(qgetenv(key)) == val
  qunsetenv(key)
  @test !haskey(ENV, key)
end
