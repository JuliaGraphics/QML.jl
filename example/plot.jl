using Test
using QML
using Plots

# No Python gui:
ENV["MPLBACKEND"] = "Agg"

function init_backend(width::Float64, height::Float64, bestr::AbstractString)
  if width < 5 || height < 5
    return
  end

  be = Symbol(lowercase(bestr))
  if be == :gr
    gr(size=(Int64(round(width)),Int64(round(height))))
    Plots.GR.inline()
  end

  return
end

function plotsin(d::JuliaDisplay, amplitude::Float64, frequency::Float64)
  if backend_name() == :none
    return
  end

  x = 0:π/100:π
  f = amplitude*sin.(frequency.*x)

  plt = plot(x,f,ylims=(-5,5),show=false)
  display(d, plt)
  #close()

  return
end

@qmlfunction plotsin init_backend

qml_file = joinpath(dirname(@__FILE__), "qml", "plot.qml")
loadqml(qml_file)

# Run the application
exec()
