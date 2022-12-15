using Base: process_status
using Test

import QML
using Documenter: doctest

excluded = ["runtests.jl", "qml", "include", "runexamples.jl"]
included = ["qqmlcomponent.jl"]

testfiles = filter(fname -> fname ∉ excluded, readdir(@__DIR__))
# testfiles = filter(fname -> fname ∈ included, readdir(@__DIR__))

@testset "QML tests" begin
  @testset "$f" for f in testfiles
    println("Running tests from $f")
    include(f)
  end
end

doctest(QML, fix=true)

# import LibGit2

# withenv("JULIA_LOAD_PATH" => nothing, "JULIA_GR_PROVIDER" => "BinaryBuilder") do
#   mktempdir() do tmpd
#     cd(tmpd) do
#       examplesdir = mkdir("QmlJuliaExamples")
#       LibGit2.clone("https://github.com/barche/QmlJuliaExamples.git", examplesdir; branch="qt6")
#       cd(examplesdir) do
#         qmlpath = dirname(dirname(pathof(QML)))
#         updatecommand = """
#           using Pkg
#           pkg"develop $qmlpath"
#           pkg"instantiate"
#           pkg"precompile"
#           pkg"status"
#         """
#         run(`$(Base.julia_cmd()) --project -e "$updatecommand"`)
#         QML.runexamples()
#       end
#     end
#     println(pwd())
#   end
# end
