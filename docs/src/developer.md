# Developer documentation

## Building the documentation locally

If not mentioned otherwise I assume that you are using the `bash` terminal. On Windows you can install
it using this software: https://gitforwindows.org/ . Be careful: The included bash terminal is not fully compatible with the [juliaup](https://github.com/JuliaLang/juliaup) Julia installer. If you are using [juliaup](https://github.com/JuliaLang/juliaup) either use the `bash` terminal from VSCode, or install [Windows Terminal](https://apps.microsoft.com/detail/windows-terminal/9N0DX20HK701).

To build the documentation locally:
- add the package `TestEnv` to your global Julia environment  
  ```julia
  using Pkg
  Pkg.add("TestEnv")
  ```
- create a fork of the QML.jl repository by going to [QML.jl](https://github.com/JuliaGraphics/QML.jl) and
clicking on the button "Fork" on the top right
- check it out locally using git, e.g. with the command  
  ```bash
  git clone https://github.com/USERNAME/QML.jl.git
  ```
  where USERNAME is your github user name.
- navigate to the new folder `QML.jl` folder and start julia with `julia --project`
- instantiate the project with
  ```julia
  using Pkg
  Pkg.instantiate()
  ```
- activate the test environment with
  ```julia
  using TestEnv; TestEnv.activate()
  ```
- now you can build and view the documentation with
  ```julia
  using LiveServer
  servedocs()
  ```

And click on the link [http://localhost:8080](http://localhost:8080) to see the documentation.

## Contributing
We need more people who help with improving the documentation, fixing bugs and with keeping the package up-to-date. You can see open documentation issues [here](https://github.com/JuliaGraphics/QML.jl/issues?q=is%3Aopen+is%3Aissue+label%3Adocumentation), open bugs [here](https://github.com/JuliaGraphics/QML.jl/issues?q=is%3Aopen+is%3Aissue+label%3A%22bug%22), and there are of course also open feature requests and ideas to create a new add-on packages, e.g.
- a package for improved [Makie](https://github.com/MakieOrg/Makie.jl) integration
- a package for improved [GR](https://github.com/jheinen/GR.jl) integration
- a package for displaying and editing [DataFrames](https://dataframes.juliadata.org/stable/)

You can get in touch with the current developers either on [Discourse](https://discourse.julialang.org/) or via [JuliaGraphics](https://github.com/orgs/JuliaGraphics/discussions). 

## Creating a pull request
If you made changes to the documentation (or any change to the code), please push these changes to your fork and then create a pull request by clicking on the "Contribute" button on the github page of your fork. Before doing that make sure your fork is in sync with the main branch of QML.jl.

## Related packages
Some changes to QML.jl might require changes to one or more of the following, related packages:

- [https://github.com/barche/QmlJuliaExamples](https://github.com/barche/QmlJuliaExamples)  
  Changes to QML.jl might require changes to the examples. Furthermore, when running the QML tests also
  these examples are executed, so changes to the examples might even brake these tests.
- [https://github.com/JuliaGraphics/jlqml](https://github.com/JuliaGraphics/jlqml)
  This is the C++ interface package that glues Julia with the QT libraries.
- [https://github.com/JuliaBinaryWrappers/Qt6Wayland_jll.jl](https://github.com/JuliaBinaryWrappers/Qt6Wayland_jll.jl)  
  The only direct dependency on a (binary) jll package. There are many more indirect binary dependencies,
  mainly for the QT packages.