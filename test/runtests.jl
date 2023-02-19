using Base: process_status
using Test

import QML
using Documenter: doctest

excluded = ["runtests.jl", "qml", "include", "runexamples.jl"]
included = ["functions.jl", "julia_arrays.jl"]

testfiles = filter(fname -> fname ∉ excluded, readdir(@__DIR__))
# testfiles = filter(fname -> fname ∈ included, readdir(@__DIR__))

@testset "QML tests" begin
  @testset "$f" for f in testfiles
    println("Running tests from $f")
    include(f)
  end
end

doctest(QML)

import LibGit2

withenv("JULIA_LOAD_PATH" => nothing, "JULIA_GR_PROVIDER" => "BinaryBuilder") do
  mktempdir() do tmpd
    cd(tmpd) do
      examplesdir = mkdir("QmlJuliaExamples")
      LibGit2.clone("https://github.com/barche/QmlJuliaExamples.git", examplesdir; branch="qt6")
      cd(examplesdir) do
        allowmakie = true
        if get(ENV, "CI", "false") == "true" && (Sys.isapple() || Sys.iswindows())
          allowmakie = false
          filtered = filter(l -> !contains(l, "Makie"), collect(eachline("Project.toml")))
          open("Project.toml", "w") do output
            for l in filtered
              println(output, l)
            end
          end
        end

        qmlpath = replace(dirname(dirname(pathof(QML))), "\\" => "/")
        cxxpath = replace(dirname(dirname(pathof(QML.CxxWrap))), "\\" => "/")
        updatecommand = """
          using Pkg
          Pkg.develop([PackageSpec(path="$qmlpath"), PackageSpec(path="$cxxpath")])
          Pkg.precompile()
        """
        run(`$(Base.julia_cmd()) --project -e "$updatecommand"`)
        QML.runexamples(allowmakie)
      end
    end
    println(pwd())
  end
end
