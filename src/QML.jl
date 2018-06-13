module QML

@static if is_windows()
  ENV["QML_PREFIX_PATH"] = joinpath(dirname(dirname(@__FILE__)),"deps","usr")
end

using CxxWrap

const depsfile = joinpath(dirname(dirname(@__FILE__)), "deps", "deps.jl")
if !isfile(depsfile)
  error("$depsfile not found, package QML did not build properly")
end
include(depsfile)

const envfile = joinpath(dirname(dirname(@__FILE__)), "deps", "env.jl")
if isfile(envfile)
  include(envfile)
end

wrap_module(_l_qml_wrap, QML)

function __init__()
  # Make sure we have an application at module load, so any QObject is created after this
  @static if is_windows()
    libdir = joinpath(dirname(dirname(@__FILE__)),"deps","usr","lib")
    for fname in readdir(libdir)
      if endswith(fname, ".dll")
        Libdl.dlopen(joinpath(libdir,fname), Libdl.RTLD_GLOBAL)
      end
    end
  end
end

"""
Overloads for getting a property value based on its name for any base class
"""
generic_property_get(ctx::QQmlContext, key::AbstractString) = context_property(ctx, key)
generic_property_get(o::JuliaObject, key::AbstractString) = julia_object_value(o, key)

"""
Expand an expression of the form a.b.c to replace the dot operator by function calls:
`@expand_dots a.b.c.d f` returns `f(f(f(a,"b"),"c"),"d")`
"""
macro expand_dots(source_expr, func)
  if source_expr.head == :escape
    source_expr = source_expr.args[1]
  end
  if isa(source_expr, Expr) && source_expr.head == :(.)
    return :($func(@expand_dots($(esc(source_expr.args[1])), $func), $(string(source_expr.args[2].args[1]))))
  end
  return esc(source_expr)
end

"""
Get a property from the Qt hierarchy using ".":
```
@qmlget o.a.b
```
returns the value of property with name "b" of property with name "a" of the root object o
"""
macro qmlget(dots_expr)
  :(@expand_dots($(esc(dots_expr)), generic_property_get))
end

# Specialize for Reals
function set_context_property(ctx::QQmlContext, key::AbstractString, value::Real)
  invoke(set_context_property, Tuple{QQmlContext, AbstractString, Any}, ctx, key, convert(Float64,value))
  return nothing
end

"""
Overloads for setting a property value based on its name for any base class
"""
generic_property_set(ctx::QQmlContext, key::AbstractString, value::Any) = set_context_property(ctx, key, value)
generic_property_set(o::JuliaObject, key::AbstractString, value::Any) = set(o, key, value)

"""
Setter version of `@qmlget`, use in the form:
```
@qmlset o.a.b = value
```
"""
macro qmlset(assign_expr)
  :(generic_property_set(@expand_dots($(esc(assign_expr.args[1].args[1])), generic_property_get), $(string(assign_expr.args[1].args[2].args[1])), $(esc(assign_expr.args[2]))))
end

"""
Emit a signal in the form:
```
@emit signal_name(arg1, arg2)
```
"""
macro emit(expr)
  esc(:(emit($(string(expr.args[1])), Any[$(expr.args[2:end]...)])))
end

"""
Register a Julia function for access from QML:
```
@qmlfunction MyFunc
```
"""
macro qmlfunction(fnames...)
  result = quote end
  for fname in fnames
    push!(result.args, :(qmlfunction($(esc(string(fname))), $(esc(fname)))))
  end

  return result
end

"""
Load the given QML path using a QQmlApplicationEngine, initializing the context with the given properties
"""
macro qmlapp(path, context_properties...)
  result = quote
    qml_engine = init_qmlapplicationengine()
  end
  for p in context_properties
    push!(result.args, :(set_context_property(qmlcontext(), $(esc(string(p))), $(esc(p)))))
  end
  push!(result.args, :(load(qml_engine, $(esc(path)))))
  return result
end

function Base.display(d::JuliaDisplay, x)
  buf = IOBuffer()
  supported_types = (MIME"image/svg+xml"(), MIME"image/png"())
  write_methods = (load_svg, load_png)
  written = false
  for (t,write_method) in zip(supported_types, write_methods)
    if mimewritable(t,x)
      Base.show(buf, t, x)
      write_method(d, take!(buf))
      written = true
      break
    end
  end
  if !written
    throw(ErrorException("Can't display using any of the types $supported_types"))
  end

end

function Base.displayable(d::JuliaDisplay, mime::AbstractString)
  if mime == "image/png"
    return true
  end
  return false
end

export @qmlget, @qmlset, @emit, @qmlfunction, @qmlapp, qmlfunction

glvisualize_include() = joinpath(dirname(@__FILE__), "glvisualize_callbacks.jl")

"""
Constructor for ListModel that automatically copies a typed array into an Array{Any,1} and creates a constructor and setter and getter functions for each field if addroles == true
"""
function ListModel{T}(a::Array{T}, addroles=true)
  any_array = Array{Any,1}(a)
  function update_array()
    n = length(any_array)
    resize!(a,n)
    for i = 1:n
      a[i] = any_array[i]
    end
  end

  listmodel = ListModel(any_array, update_array)

  if nfields(T) > 0 && addroles
    for fname in fieldnames(T)
      addrole(listmodel, string(fname), (x) -> getfield(x, fname), (array, value, index) -> setfield!(array[index], fname, value))
    end
    setconstructor(listmodel, T)
  end

  return listmodel
end

# ListModel Julia interface
Base.push!(lm::ListModel, val) = push_back(lm, val)
Base.size(lm::ListModel) = (model_length(lm),)
Base.length(lm::ListModel) = model_length(lm)
Base.delete!(lm::ListModel, i) = remove(lm, i-1)

@doc """
Module for building [Qt5 QML](http://doc.qt.io/qt-5/qtqml-index.html) graphical user interfaces for Julia programs.
Types starting with `Q` are equivalent of their Qt C++ counterpart, so they have no Julia docstring and we refer to
the [Qt documentation](http://doc.qt.io/qt-5/qtqml-index.html) for details instead.
""" QML

@doc """
Equivalent to [`QQmlContext::setContextProperty`](http://doc.qt.io/qt-5/qqmlcontext.html#setContextProperty).

This function is useful to expose Julia values to  Current properties can be fundamental numeric types,
strings and any `QObject`.

Example:
```julia
qml_engine = QQmlApplicationEngine()
root_ctx = root_context(qml_engine)
set_context_property(root_ctx, "my_property", 1)
```

You can now use `my_property` in QML and every time `set_context_property` is called on it the GUI gets notified.
""" set_context_property

@doc "Equivalent to [`QQmlEngine::rootContext`](http://doc.qt.io/qt-5/qqmlengine.html#rootContext)" root_context

@doc """
Equivalent to [`&QQmlApplicationEngine::load`](http://doc.qt.io/qt-5/qqmlapplicationengine.html#load-1). The first argument is
the application engine, the second is a string containing a path to the local QML file to load.
""" load

@doc "Equivalent to `QLibraryInfo::location(QLibraryInfo::PrefixPath)`" qt_prefix_path
@doc "Equivalent to `QQuickWindow::contentItem`" content_item
@doc "Equivalent to `QQuickView::setSource`" set_source
@doc "Equivalent to `QQuickView::show`" show
@doc "Equivalent to `QQuickView::engine`" engine
@doc "Equivalent to `QQuickView::rootObject`" root_object

@doc "Equivalent to `QByteArray::toString`" to_string

@doc """
Equivalent to `QQmlComponent::setData`. Use this to set the QML code for a QQmlComponent from a Julia string literal.
""" set_data

@doc """
Equivalent to `QQmlComponent::create`. This creates a component defined by the QML code set using `set_data`.
It also makes sure the newly created object is parented to the given context.
""" create

@doc """
qmlfunction(name, function)

Register the given function using the given name. Useful for registering functions from a non-exported module or renaming a function upon register (e.g. removing the !)

""" qmlfunction

end
