function runexamples()
  ENV["QT_LOGGING_RULES"] = "qt.scenegraph.time.renderloop=true;"
  excluded = String[]

  renderstring = "Frame rendered"

  function errorfilter(line)
    return !Base.contains(line, renderstring)
  end

  for fname in readdir()
    if endswith(fname, ".jl") && fname ∉ excluded
      if any(Base.contains.(readlines(fname),"exec_async"))
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
        rendered = Base.contains(errstr, renderstring)
        if current_time >= 300.0 || rendered
          sleep(0.5)
          kill(testproc)
          break
        end
      end
      outstr = String(take!(outbuf))
      errlines = join(filter(errorfilter, split(errstr, r"[\r\n]+")), "\n")
      if !rendered || Base.contains(lowercase(errlines), "error")
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
