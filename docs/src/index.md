# QML

## Loading

We support three methods of loading a QML file: [`QML.QQmlApplicationEngine`](@ref),
[`QML.QQuickView`](@ref) and [`QQmlComponent`](@ref). These behave equivalently to the
corresponding Qt classes. They have different advantages:

- You can simply load a QML file using the [`loadqml`](@ref) function as a [`QML.QQmlApplicationEngine`](@ref).
- [`QML.QQuickView`](@ref) creates a window, so it's not necessary to wrap the QML in `ApplicationWindow`.
- You can run QML code contained in a string with [`QQmlComponent`](@ref).

## QML modules

Since QML.jl version 0.2, only the `QtDeclarative` package is installed by default, which includes only a very limited set of QML modules.

## Interaction

Interaction with Julia happens through the following mechanisms:

* Call Julia functions from QML, e.g. with [`@qmlfunction`](@ref).
* Read and set context properties from Julia and QML, e.g. with keywords to [`loadqml`](@ref) or [`set_context_property`](@ref).
* Emit signals from Julia to QML, e.g. with [`@emit`](@ref).
* Use data models, e.g. [`JuliaItemModel`](@ref) or [`JuliaPropertyMap`](@ref).

Note that Julia slots appear missing, but they are not needed since it is possible to directly connect a Julia function to a QML signal in the QML code, e.g. with [`QTimer`](@ref).

## Type conversion
Most fundamental types are converted implicitly. Mind that the default integer type in QML corresponds to `Int32` in Julia.

We also convert `QVariantMap`, exposing the indexing operator `[]` to access element by a string key. This mostly to deal with arguments passed to the QML `append` function in list models.

## Using QML.jl inside another Julia module

Because of precompilation and because the QML engine gets destroyed between runs, care needs to be taken to avoid storing invalid pointers and to call all `@qmlfunction` macros again before restarting the program. An example module that takes care of this could look like this:

```julia
module QmlModuleTest

using QML
# absolute path in case working dir is overridden
const qml_file = joinpath(dirname(@__FILE__), "qml", "frommodule.qml")

# Propertymap is a pointer, so it needs to be a function and not a const value
props() = JuliaPropertyMap(
    "hi" => "Hi",
)

world() = " world!"

# Convenience function to call all relevant function macros
function define_funcs()
  @qmlfunction world
end

function main()
  define_funcs()
  loadqml(qml_file; props=props())
  exec()
end

end # module QmlModuleTest
```

The referred `frommodule.qml` file is expected in a subdirectory called `qml`, with the following content:

```qml
import QtQuick
import QtQuick.Controls
import jlqml

ApplicationWindow {
  id: mainWin
  title: "My Application"
  width: 100
  height: 100
  visible: true

  Rectangle {
    anchors.fill: parent
    color: "red"

    Text {
      anchors.centerIn: parent
      text: props.hi + Julia.world()
    }
  }
}
```

## Interface

```@index
Modules = [QML]
```

```@autodocs
Modules = [QML]
```
