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

import LibGit2

mktempdir() do tmpd
  cd(tmpd) do
    examplesdir = mkdir("QmlJuliaExamples")
    LibGit2.clone("https://github.com/barche/QmlJuliaExamples.git", examplesdir)
    cd(examplesdir) do
      qmlpath = dirname(dirname(pathof(QML)))
      updatecommand = """
        using Pkg
        pkg"develop $qmlpath"
        pkg"status"
      """
      run(`$(Base.julia_cmd()) --project -e "$updatecommand"`)
      run(`$(Base.julia_cmd()) --project runexamples.jl`)
    end
  end
  println(pwd())
end
