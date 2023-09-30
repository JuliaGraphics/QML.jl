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

## Interface

```@index
Modules = [QML]
```

```@autodocs
Modules = [QML]
```
