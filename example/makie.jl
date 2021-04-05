# MUST disable threading in Qt
ENV["QSG_RENDER_LOOP"] = "basic"

using CxxWrap
using Observables
using QML
using Makie

const catangle = Observable(0.0)
const cat = mesh(Makie.loadasset("cat.obj"), color = :blue)
const lastrot = Ref(0.0)

# Render function that takes a parameter t from a QML slider
function render_function(screen)
  rotate_cam!(cat, (catangle[] - lastrot[])*π/180, 0.0, 0.0)
  lastrot[] = catangle[]
  display(screen, cat)
end

loadqml(joinpath(dirname(@__FILE__), "qml", "makie.qml"),
  cat = JuliaPropertyMap("angle" => catangle),
  render_callback = @safe_cfunction(render_function, Cvoid, (Any,))
)
exec()
