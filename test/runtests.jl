using Test

import QML
using Documenter: doctest

excluded = ["runtests.jl", "qml", "include"]

testfiles = filter(fname -> fname ∉ excluded, readdir(@__DIR__))

@testset "QML tests" begin
  @testset "$f" for f in testfiles
    println("Running tests from $f")
    include(f)
  end
end

doctest(QML, fix=true)
