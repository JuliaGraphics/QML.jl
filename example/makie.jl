# MUST disable threading in Qt
ENV["QSG_RENDER_LOOP"] = "basic"

using CxxWrap
using Observables
using QML
using GLMakie

const catangle = Observable(0.0)
const scene = Scene()
const cat = mesh(loadasset("cat.obj"), color = :blue)
const lastrot = Ref(0.0)

# Render function that takes a parameter t from a QML slider
function render_function(screen)
  # Rotation needs to be fixed later
  # rotate_cam!(scene, (catangle[] - lastrot[]) * π/180, 0.0, 0.0)
  lastrot[] = catangle[]
  display(screen, scene)
end

load(joinpath(dirname(@__FILE__), "qml", "makie.qml"),
  cat = JuliaPropertyMap("angle" => catangle),
  render_callback = @safe_cfunction(render_function, Cvoid, (Any,))
)
exec()
