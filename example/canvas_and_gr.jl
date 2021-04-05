ENV["QSG_RENDER_LOOP"] = "basic" # multithreading in Qt must be off

using QML
using Observables
using Plots
using ColorTypes
using CxxWrap # for safe_cfunction, CxxPtr

const qmlfile = joinpath(dirname(Base.source_path()), "qml", "canvas_and_gr.qml")

ENV["GKSwstype"] = "use_default"
ENV["GKS_WSTYPE"] = 381
ENV["GKS_QT_VERSION"] = 5
gr(show=true)

invert_sin = Observable(-1)
amplitude = Observable(-1.0)
frequency = Observable(-1.0)
diameter = Observable(-1.0)
description_text = Observable("")

function paint_sin_plot(p::CxxPtr{QPainter}, item::CxxPtr{JuliaPaintedItem})  
    ENV["GKS_CONID"] = split(repr(p.cpp_object), "@")[2]
    dev = device(p[])[]
    r = effectiveDevicePixelRatio(window(item[])[])
    w, h = width(dev) / r, height(dev) / r

    x = 0:π/1000:π
    y = amplitude[]*sin.(frequency[]*x)
    if invert_sin[] == true
        y = -y
    end

    plot(x, y, ylims=(-5,5), size=(w, h))

    return
end

function paint_cos_plot(p::CxxPtr{QPainter}, item::CxxPtr{JuliaPaintedItem})  
    ENV["GKS_CONID"] = split(repr(p.cpp_object), "@")[2]
    dev = device(p[])[]
    r = effectiveDevicePixelRatio(window(item[])[])
    w, h = width(dev) / r, height(dev) / r

    x = 0:π/1000:π
    y = amplitude[]*cos.(frequency[]*x)

    plot(x, y, ylims=(-5,5), size=(w, h))

    return
end

################## canvas ########################    
# fix callback arguments (TODO: macro this?)
function paint_canvas(buffer::Array{UInt32, 1},
                      width32::Int32,
                      height32::Int32)
    width::Int = width32
    height::Int = height32
    buffer = reshape(buffer, width, height)
    buffer = reinterpret(ARGB32, buffer)
    paint_circle(buffer)
end

# callback to paint circle
function paint_circle(buffer)
    width, height = size(buffer)

    center_x = width/2
    center_y = height/2
    rad2 = (diameter[]/2)^2
    for x in 1:width
        for y in 1:height
            if (x-center_x)^2 + (y-center_y)^2 < rad2
                buffer[x,y] = ARGB32(1, 0, 0, 1) #red
            else
                buffer[x,y] = ARGB32(0, 0, 0, 1) #black
            end
            if x < 10
                buffer[x,y] = ARGB32(1, 0, 0, 1) # red
            end
            if y < 10
                buffer[x,y] = ARGB32(0, 0, 1, 1) # blue
            end
            if x == y
                if y < height/2
                    buffer[x,y] = ARGB32(0, 1, 0, 1) # green
                else
                    buffer[x,y] = ARGB32(1, 1, 0, 1) # yellow
                end
            end
        end
    end
    return
end

onany(amplitude, frequency, invert_sin, diameter) do amp, freq, inv, dia
    amp  = round(amp, digits=2)
    freq = round(freq, digits=2)
    dia  = round(dia, digits=2)

    description_text[]="""<table>
    
<tr> <td>amp<\td> <td>$amp</b> </tr>
<tr> <td>freq<\td> <td>$freq</b> </tr>
<tr> <td>diameter<\td> <td>$dia</b> </tr>
</table>"""

    if inv==true
        description_text[] *= "<i>The sin wave is inverted.</i>"
    end
end

loadqml(qmlfile,
     parameters = JuliaPropertyMap(
     "invert_sin"       => invert_sin,
     "amplitude"        => amplitude,
     "frequency"        => frequency,
     "diameter"         => diameter,
     "description_text" => description_text),
     paint_sin_plot_wrapped = @safe_cfunction(paint_sin_plot, Cvoid,
                                              (CxxPtr{QPainter}, CxxPtr{JuliaPaintedItem})),
     paint_cos_plot_wrapped = @safe_cfunction(paint_cos_plot, Cvoid,
                                              (CxxPtr{QPainter}, CxxPtr{JuliaPaintedItem})),
     paint_canvas_wrapped = @safe_cfunction(paint_canvas, Cvoid,
                                            (Array{UInt32,1}, Int32, Int32))
     )

onany(amplitude, frequency, invert_sin) do a, f, i
    @emit updateSinPlot()
    @emit updateCosPlot()
end

on(diameter) do d
    @emit updateCanvas()
end

exec()
