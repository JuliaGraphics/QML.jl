using Base: process_status
using Test

import QML
using Documenter: doctest

excluded = ["runtests.jl", "qml", "include", "runexamples.jl"]

testfiles = filter(fname -> fname ∉ excluded, readdir(@__DIR__))

@testset "QML tests" begin
  @testset "$f" for f in testfiles
    println("Running tests from $f")
    include(f)
  end
end

doctest(QML, fix=true)

function runexamples()
  ENV["QT_LOGGING_RULES"] = "qt.scenegraph.time.renderloop=true;"

  renderstring = "Frame rendered"

  function errorfilter(line)
    return !contains(line, renderstring)
  end

  for fname in readdir()
    if endswith(fname, ".jl") && fname ∉ excluded
      if any(contains.(readlines(fname),"exec_async"))
        println("Skipping async example $fname")
        continue
      end
      println("running example ", fname, "...")
      outbuf = IOBuffer()
      errbuf = IOBuffer()
      testproc = run(pipeline(`$(Base.julia_cmd()) --project $fname`; stdout=outbuf, stderr=errbuf); wait = false)
      current_time = 0.0
      timestep = 0.1
      errstr = ""
      rendered = false
      while process_running(testproc)
        sleep(timestep)
        current_time += timestep
        errstr *= String(take!(errbuf))
        rendered = contains(errstr, renderstring)
        if current_time >= 300.0 || rendered
          sleep(0.5)
          kill(testproc)
          break
        end
      end
      outstr = String(take!(outbuf))
      errlines = join(filter(errorfilter, split(errstr, r"[\r\n]+")), "\n")
      if !rendered || contains(lowercase(errlines), "error")
        throw(ErrorException("Example $fname errored with output:\n$outstr\nand error:\n$errlines"))
      elseif isempty(outstr) && isempty(errlines)
        println("Example $fname finished")
      elseif isempty(outstr)
        println("Example $fname finished with error:\n$errlines")
      else
        println("Example $fname finished with output:\n$outstr")
      end
    end
  end
end

import LibGit2

withenv("JULIA_LOAD_PATH" => nothing, "JULIA_GR_PROVIDER" => "BinaryBuilder") do
  mktempdir() do tmpd
    cd(tmpd) do
      examplesdir = mkdir("QmlJuliaExamples")
      LibGit2.clone("https://github.com/barche/QmlJuliaExamples.git", examplesdir)
      cd(examplesdir) do
        qmlpath = dirname(dirname(pathof(QML)))
        updatecommand = """
          using Pkg
          pkg"develop $qmlpath"
          pkg"instantiate"
          pkg"precompile"
          pkg"status"
        """
        run(`$(Base.julia_cmd()) --project -e "$updatecommand"`)
        runexamples()
      end
    end
    println(pwd())
  end
end
