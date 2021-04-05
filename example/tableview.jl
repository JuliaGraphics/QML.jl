using Test
using QML
using Observables

struct Nuclide
  name::String
  values::Dict{Int,Float64}
end

const years = Observable(collect(Cint,2016:2025)) # exposed as context property
nuclides = [Nuclide(name, Dict([(y,rand()) for y in years[]])) for name in ["Co60", "Cs137", "Ni63"]]
nuclidesModel = ListModel(nuclides, false)
addrole(nuclidesModel, "name", n -> n.name)

# Seems roles can't start with a number
add_year_role(model, year::Integer) = addrole(model, "y" * string(year), n -> round(n.values[year]; digits=2))

# add year roles manually:
for y in years[]
  add_year_role(nuclidesModel, y)
end

on(years) do ys
  ys_int = Int.(QML.value.(ys))
  roleints = parse.(Int,getindex.(roles(nuclidesModel)[2:end], Ref(2:5)))
  addyears!(nuclidesModel, nuclides, setdiff(ys_int, roleints))
  delyears!(nuclidesModel, nuclides, setdiff(roleints, ys_int))
end

function addyears!(model, nuclides, years)
  for y in years
    for nuc in nuclides
      nuc.values[y] = rand()
    end
    add_year_role(model, y)
  end
end

function delyears!(model, nuclides, years)
  for y in years
    for nuc in nuclides
      delete!(nuc.values, y)
    end
    removerole(model, "y"*string(y))
  end
end

# Load QML after setting context properties, to avoid errors on initialization
qml_file = joinpath(dirname(@__FILE__), "qml", "tableview.qml")
loadqml(qml_file, properties=JuliaPropertyMap("years" => years), nuclidesModel=nuclidesModel)

# Run the application
exec()
