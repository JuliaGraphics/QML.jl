using Test
using QML

function emit_signal1()
  @emit testsignal()
end

function emit_signal2()
  @emit testsignalargs(2., "Hi from Julia")
end

function check1(result::Bool)
  @test result
  nothing
end

function check2(x::Float64, s::AbstractString)
  @test x == 2.
  @test s == "Hi from Julia"
  nothing
end

@qmlfunction emit_signal1
@qmlfunction emit_signal2
@qmlfunction check1 check2

# absolute path in case working dir is overridden
qml_file = joinpath(dirname(@__FILE__), "qml", "julia_signal.qml")

loadqml(qml_file)

# Run the application
exec()
