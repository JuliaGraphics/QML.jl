using Test

import QML
using Documenter: doctest

doctest(QML, fix=true)

excluded = ["runtests.jl", "qml", "include"]

testfiles = filter(fname -> fname ∉ excluded, readdir())

@testset "QML tests" begin
  @testset "$f" for f in testfiles
    println("Running tests from $f")
    include(f)
  end
end
