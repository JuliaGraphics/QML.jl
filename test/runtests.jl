using Test

import QML
using Documenter: doctest

doctest(QML, fix=true)

excluded = ["runtests.jl", "qml", "include"]

# OpenGL on Linux travis is excessively old, causing a crash when attempting display of a window
if get(ENV, "QML_SKIP_GUI_TESTS", "0") != "0"
  excluded = [excluded; ["listviews.jl", "qqmlcomponent.jl", "qquickview.jl"]]
end

testfiles = filter(fname -> fname ∉ excluded, readdir())

@testset "QML tests" begin
  @testset "$f" for f in testfiles
    println("Running tests from $f")
    include(f)
  end
end
