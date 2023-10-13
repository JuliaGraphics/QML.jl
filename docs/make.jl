using QML
using Documenter: deploydocs, makedocs

makedocs(;
    authors="Bart Janssens, Uwe Fechner <fechner@aenarete.eu> and contributors",
    sitename = "QML.jl", 
    modules = [QML], 
    doctest = false,
    pages=[
        "QML" => "index.md",
        "Developer" => "developer.md",
    ])
deploydocs(repo = "github.com/JuliaGraphics/QML.jl.git")
