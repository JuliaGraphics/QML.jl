module QML

using ColorTypes: include
export QVariant, QString, QUrl
export QQmlContext, root_context, loadqml, qt_prefix_path, set_source, engine, QByteArray, to_string, QQmlComponent, set_data, create, QQuickItem, content_item, QTimer, context_property, emit, JuliaDisplay, JuliaCanvas, init_application, qmlcontext, init_qmlapplicationengine, init_qmlengine, init_qquickview, exec, exec_async, ListModel, addrole, setconstructor, removerole, setrole, roles, QVariantMap
export JuliaPropertyMap
export QStringList, QVariantList
export QPainter, device, width, height, logicalDpiX, logicalDpiY, QQuickWindow, effectiveDevicePixelRatio, window, JuliaPaintedItem
export @emit, @qmlfunction, qmlfunction, QQmlPropertyMap
export set_context_property
export QUrlFromLocalFile
export qputenv, qgetenv, qunsetenv

# TODO: Document: init_application, init_qmlapplicationengine
# TODO: Document painter: device, effectiveDevicePixelRatio, height, JuliaCanvas, JuliaPaintedItem, logicalDpiX, logicalDpiY, width, window

using jlqml_jll

using CxxWrap
using Observables
import Libdl
using Requires
using ColorTypes
using MacroTools: @capture

const envfile = joinpath(dirname(dirname(@__FILE__)), "deps", "env.jl")
if isfile(envfile)
  include(envfile)
end

@readmodule libjlqml :define_julia_module Libdl.RTLD_GLOBAL
@wraptypes

# Make sure functions accepting a QString argument also accept a Julia string
CxxWrap.argument_overloads(::Type{<:QString}) = [QString,String]

@wrapfunctions

@cxxdereference set_context_property(ctx::QQmlContext, name, value::QObject) = _set_context_property(ctx, QString(name), CxxPtr(value))
@cxxdereference set_context_property(ctx::QQmlContext, name, value) = _set_context_property(ctx, QString(name), QVariant(value))

function load_qml(qmlfilename, engine)
  ctx = root_context(CxxRef(engine))
  if !load_into_engine(engine, QString(qmlfilename))
    error("Failed to load QML file ", qmlfilename)
  end
  return engine
end

"""
    function loadqml(qmlfilename; properties...)

Load a QML file, creating a [`QML.QQmlApplicationEngine`](@ref), and setting the context
`properties` supplied in the keyword arguments. Will create and return a
`QQmlApplicationEngine`. See the example for [`QML.QQmlApplicationEngine`](@ref).
"""
function loadqml(qmlfilename; kwargs...)
  qml_engine = init_qmlapplicationengine()
  ctx = root_context(CxxRef(qml_engine))
  for (key,value) in kwargs
    set_context_property(ctx, String(key), value)
  end
  return load_qml(qmlfilename, qml_engine)
end

@static if Sys.iswindows()
  using Mesa_jll
end

const _loaded_qml_modules = Module[]

function loadqmljll(m::Module)
  if m ∈ _loaded_qml_modules
    return
  end
  push!(_loaded_qml_modules, m)
  qmlpath(mod) = joinpath(mod.artifact_dir, "qml")
  separator = Sys.iswindows() ? ';' : ':'
  new_import_paths = join(qmlpath.(_loaded_qml_modules), separator)
  ENV["QML2_IMPORT_PATH"] = new_import_paths
  @static if Sys.iswindows() # ENV doesn't work on Windows for Qt, for reasons I forgot but that are explained on StackOverflow
    qputenv("QML2_IMPORT_PATH", QByteArray(new_import_paths))
  end
end


function __init__()
  @initcxx

  @require GLMakie="e9467ef8-e4e7-5192-8a1a-b1aee30e663a" include(joinpath(@__DIR__, "makie_support.jl"))

  # Make sure Qt can find the Mesa dll if it doesn't find a compatible OpenGL implementation
  @static if Sys.iswindows()
    qputenv("PATH", QByteArray(ENV["PATH"] * ";" * dirname(Mesa_jll.opengl32sw)))
  end

  loadqmljll(jlqml_jll.Qt5Declarative_jll)
  @require Qt5QuickControls_jll="e4aecf45-a397-53cc-864f-87db395e0248" @eval loadqmljll(Qt5QuickControls_jll)
  @require Qt5QuickControls2_jll="bf3ac11c-603e-589e-b4b7-e696ac65aa4a" @eval loadqmljll(Qt5QuickControls2_jll)
  @require Qt5Charts_jll="dd720b4e-75c8-5196-993d-eac563881c8e" @eval loadqmljll(Qt5Charts_jll)
end

# QString
function QString(s::String)
  char_arr = transcode(UInt16, s)
  return fromUtf16(char_arr, length(char_arr))
end
Base.ncodeunits(s::QString)::Int = cppsize(s)
Base.codeunit(s::QString) = UInt16
Base.codeunit(s::QString, i::Integer) = uint16char(s, i-1)
Base.isvalid(s::QString, i::Integer) = isvalidindex(s, i-1)
function Base.iterate(s::QString, i::Integer=1)
  if !isvalid(s,i)
    return nothing
  end
  (charcode, nexti) = get_iterate(s,i-1)
  if nexti == -1
    return nothing
  end
  return(Char(charcode),nexti+1)
end
Base.convert(::Type{<:QString}, s::String) = QString(s)
QString(u::QUrl) = toString(u)

const QVariantList = QList{QVariant}

# Conversion to the strongly-typed QVariant interface
@inline QVariant(x) = QVariant(Any,x)
@inline QVariant(x::T) where {T<:Union{Number,Ref,CxxWrap.SafeCFunction,QVariantMap,Nothing}} = QVariant(T, x)
@inline QVariant(x::AbstractString) = QVariant(QString,QString(x))
@inline QVariant(x::QString) = QVariant(QString,x)
@inline QVariant(x::QObject) = QVariant(CxxPtr{QObject},CxxPtr(x))
@inline QVariant(x::QVariant) = x

QVariant(::Type{Bool}, b::Bool) = QVariant(CxxBool, CxxBool(b))
@cxxdereference value(::Type{Bool}, qvar::QML.QVariant) = Bool(value(CxxBool, qvar))

function QVariant(arr::AbstractArray)
  qvarlist = QVariantList()
  for x in arr
    push!(qvarlist, x)
  end
  return QVariant(QVariantList, qvarlist)
end

@inline @cxxdereference setValue(v::QVariant, x::T) where {T} = setValue(T, v, x)
QVariant(::Type{Nothing}, ::Nothing) = QVariant()
@cxxdereference value(::Type{Nothing}, ::QML.QVariant) = nothing
@cxxdereference value(v::QVariant) = CxxWrap.dereference_argument(value(type(v),v))
Base.convert(::Type{QVariant}, x::T) where {T} = QVariant(x)
Base.convert(::Type{T}, x::QVariant) where {T} = convert(T,value(x))
Base.convert(::Type{Any}, x::QVariant) = x
Base.convert(::Type{<:QVariant}, x::QVariant) = x

@cxxdereference Base.show(io::IO, x::QVariant) = write(io, string("QVariant of type ", type(x), " with value ", value(x)))

Base.IndexStyle(::Type{<:QList}) = IndexLinear()
Base.size(v::QList) = (Int(cppsize(v)),)
Base.getindex(v::QList, i::Int) = cppgetindex(v,i-1)[]
Base.setindex!(v::QList{T}, val, i::Int) where {T} = cppsetindex!(v, convert(T,val), i-1)
function Base.push!(v::QList{T}, x) where {T}
  push_back(v, convert(T,x))
  return v
end
Base.empty!(l::QList) = clear(l)
Base.deleteat!(l::QList, i::Integer) = removeAt(l, i-1)

# Helper to call a julia function
function julia_call(f, argptr::Ptr{Cvoid})
  arglist = CxxRef{QVariantList}(argptr)[]
  result = QVariant(f((value(x) for x in arglist)...))
  return result.cpp_object
end

function get_julia_call()
  return @cfunction(julia_call, Ptr{Cvoid}, (Any,Ptr{Cvoid}))
end

# QQmlPropertyMap indexing interface
Base.getindex(propmap::QQmlPropertyMap, key::AbstractString) = value(value(propmap, key))
Base.setindex!(propmap::QQmlPropertyMap, val, key::AbstractString) = insert(propmap, QString(key), QVariant(val))
Base.setindex!(propmap::QQmlPropertyMap, val::QVariant, key::AbstractString) = insert(propmap, key, val)
Base.setindex!(propmap::QQmlPropertyMap, val::Irrational, key::AbstractString) = (propmap[key] = convert(Float64, val))

function on_value_changed end

mutable struct JuliaPropertyMap <: AbstractDict{String,Any}
  propertymap::_JuliaPropertyMap
  dict::Dict{String, Any}

  function JuliaPropertyMap()
    result = new(_JuliaPropertyMap(), Dict{String, Any}())
    set_julia_value(result.propertymap, result)
    connect_value_changed(result.propertymap, result, on_value_changed)
    finalizer(result) do jpm
      for k in keys(jpm.dict)
        delete!(jpm, k) # Call delete on all keys to detach observable updates to QML
      end
    end
    return result
  end
end

"""
    function JuliaPropertyMap(pairs...)

Store Julia values for access from QML. `Observables` are connected so they change on the
QML side when updated from Julia and vice versa only when passed in a property map. Note
that in the example below, if you run `output[] = new_value` from within Julia, the slider
in QML will move.

```jldoctest
julia> using QML

julia> using Qt5QuickControls_jll

julia> using Observables: Observable, on

julia> output = Observable(0.0);

julia> on(println, output);

julia> mktempdir() do folder
         path = joinpath(folder, "main.qml")
         write(path, \"""
         import QtQuick 2.0
         import QtQuick.Controls 1.0
         ApplicationWindow {
           visible: true
           Slider {
             onValueChanged: {
               observables.output = value;
             }
           }
           Timer {
             running: true
             onTriggered: Qt.quit()
           }
         }
         \""")
         loadqml(path; observables = JuliaPropertyMap("output" => output))
         exec()
       end
```
"""
function JuliaPropertyMap(pairs::Pair{<:AbstractString,<:Any}...)
  result = JuliaPropertyMap()
  for (k,v) in pairs
    result[k] = v
  end
  return result
end
JuliaPropertyMap(dict::Dict{<:AbstractString,<:Any}) = JuliaPropertyMap(dict...)

@cxxdereference value(::Type{JuliaPropertyMap}, qvar::QVariant) = getpropertymap(qvar)

# Functor to update a QML property when an Observable is changed in Julia
struct QmlPropertyUpdater
  propertymap::QQmlPropertyMap
  key::String
  active::Bool
end
function (updater::QmlPropertyUpdater)(x)
  updater.propertymap[updater.key] = x
end

setactive!(::Any,::Bool) = nothing
setactive!(updater::QmlPropertyUpdater, active::Bool) = (updater.active = active)

Base.getindex(jpm::JuliaPropertyMap, k::AbstractString) = jpm.dict[k]
Base.get(jpm::JuliaPropertyMap, k::AbstractString, def) = get(jpm.dict, k, def)

function Base.delete!(jpm::JuliaPropertyMap, k::AbstractString)
  storedvalue = jpm.dict[k]
  if storedvalue isa Observable
    for observer in filter(x -> x isa QmlPropertyUpdater, Observables.listeners(storedvalue))
      if observer.propertymap == jpm.propertymap
        off(storedvalue, observer)
      end
    end
  end
  delete!(jpm.dict, k)
  clear(jpm.propertymap, k)
end
function Base.setindex!(jpm::JuliaPropertyMap, val, key::AbstractString)
  jpm.propertymap[key] = val
  jpm.dict[key] = val
end
# Base.push!(jpm::JuliaPropertyMap, kv::Pair{<:AbstractString}) = setindex!(ENV, kv.second, kv.first)

function Base.setindex!(jpm::JuliaPropertyMap, ob::Observable, key::AbstractString)
  val = QVariant(ob[])
  jpm.propertymap[key] = val
  jpm.dict[key] = ob
  on(QmlPropertyUpdater(jpm.propertymap, key, true), ob)
end

Base.iterate(jpm::JuliaPropertyMap) = iterate(jpm.dict)
Base.iterate(jpm::JuliaPropertyMap, state) = iterate(jpm.dict, state)
Base.length(jpm::JuliaPropertyMap) = length(jpm.dict)

@cxxdereference function set_context_property(ctx::QQmlContext, name, jpm::JuliaPropertyMap)
  gc_name = "__jlcxx_gc_protect" * name
  set_context_property(ctx, gc_name, QVariant(jpm)) # This is to protect the jpm object from GC
  set_context_property(ctx, name, jpm.propertymap) # QML needs the QQmlPropertyMap
end

# Called upon change from QML, so QmlPropertyUpdater is excluded from the handlers
@cxxdereference function on_value_changed(jpm::JuliaPropertyMap, key::QString, variantvalue::QVariant)
  storedvalue = jpm[key]
  newvalue = value(variantvalue)
  if storedvalue isa Observable
    setactive!(Observables.listeners(storedvalue), false)
    storedvalue[] = newvalue
    setactive!(Observables.listeners(storedvalue), true)
  else
    jpm.dict[key] = newvalue
  end
end

expand_dots(source_expr, func) =
  if @capture source_expr object_.field_
    Expr(:call, func, expand_dots(object, func), String(field))
  else
    source_expr
  end

"""
    QML.@expand_dots object_.field_ func

Expand an expression of the form a.b.c to replace the dot operator by function calls.

```jldoctest
julia> using QML

julia> @macroexpand QML.@expand_dots a.b.c.d f
:(f(f(f(a, "b"), "c"), "d"))
```
"""
macro expand_dots(source_expr, func)
  esc(expand_dots(source_expr, func))
end

function emit(name, args...)
  arglist = QVariantList()
  for arg in args
    push!(arglist, QVariant(arg))
  end
  emit(name, arglist)
end

"""
    @emit signal_name(arguments...)

Emit a signal from Julia to QML. Handle signals in QML using a `JuliaSignals` block. See the
example below for syntax.

!!! warning
    There must never be more than one JuliaSignals block in QML

```jldoctest
julia> using QML

julia> using Qt5QuickControls_jll

julia> duplicate(value) = @emit duplicateSignal(value);

julia> @qmlfunction duplicate

julia> mktempdir() do folder
          path = joinpath(folder, "main.qml")
          write(path, \"""
          import QtQuick 2.2
          import QtQuick.Controls 1.1
          import QtQuick.Layouts 1.1
          import org.julialang 1.0
          ApplicationWindow {
              visible: true
              Column {
                TextField {
                    id: input
                    onTextChanged: Julia.duplicate(text)
                }
                Text {
                    id: output
                }
                JuliaSignals {
                  signal duplicateSignal(var value)
                  onDuplicateSignal: output.text = value
                }
                Timer {
                  running: true
                  onTriggered: Qt.quit()
                }
              }
          }
          \""")
          loadqml(path)
          exec()
        end
```
"""
macro emit(expr)
  esc(:(emit($(string(expr.args[1])), $(expr.args[2:end]...))))
end

"""
    @qmlfunction function_names...

Register Julia functions for access from QML under their own name. Function names must be
valid in QML, e.g. they can't contain `!`. You can use your newly registered functions in
QML by first importing `org.julialang 1.0`, and then calling them with
`Julia.function_name(arguments...)`. If you would like to register a function under a
different name, use [`qmlfunction`](@ref). This will be necessary for non-exported functions
from a different module or in case the function contains a `!` character.

```jldoctest
julia> using QML

julia> using Qt5QuickControls_jll

julia> greet() = "Hello, World!";

julia> @qmlfunction greet

julia> mktempdir() do folder
          path = joinpath(folder, "main.qml")
          write(path, \"""
          import org.julialang 1.0
          import QtQuick 2.0
          import QtQuick.Controls 1.0
          ApplicationWindow {
            visible: true
            Text {
              text: Julia.greet()
            }
            Timer {
              running: true
              onTriggered: Qt.quit()
            }
          }
          \""")
          loadqml(path)
          exec()
        end
```
"""
macro qmlfunction(fnames...)
  result = quote end
  for fname in fnames
    push!(result.args, :(qmlfunction($(esc(string(fname))), $(esc(fname)))))
  end

  return result
end

function qmlapp(path::AbstractString)
  qml_engine = init_qmlapplicationengine()
  return load_into_engine(qml_engine, path)
end


function Base.display(d::JuliaDisplay, x)
  buf = IOBuffer()
  supported_types = (MIME"image/svg+xml"(), MIME"image/png"())
  write_methods = (load_svg, load_png)
  written = false
  for (t,write_method) in zip(supported_types, write_methods)
    if showable(t,x)
      Base.show(buf, t, x)
      write_method(d, take!(buf))
      written = true
      break
    end
  end
  if !written
    throw(MethodError(display, (d,x)))
  end

end

function Base.displayable(d::JuliaDisplay, mime::AbstractString)
  if mime == "image/png"
    return true
  end
  return false
end

struct ListModelFunctionUndefined <: Exception end
defaultsetter(array, value, index) = throw(ListModelFunctionUndefined())
defaultconstructor(roles...) = throw(ListModelFunctionUndefined())

mutable struct ListModelData
  values::AbstractVector
  roles::QStringList
  getters::Vector{Any}
  setters::Vector{Any}
  constructor
  customroles::Bool

  function ListModelData(values::AbstractVector)
    roles = QStringList()
    return new(values, roles, [], [], defaultconstructor, false)
  end
end

rowcount(m::ListModelData) = Int32(length(m.values))
rolenames(m::ListModelData) = m.roles

function data(m::ListModelData, row::Integer, role::Integer)
  if row ∉ axes(m.values,1)
    @warn "row $row is out of range for listmodel"
    return QVariant()
  end
  @assert length(rolenames(m)) == length(m.getters)
  return QVariant(m.getters[role](m.values[row]))
end

@cxxdereference function setdata(m::ListModelData, row::Integer, val::QVariant, role::Integer)
  if row ∉ axes(m.values,1)
    @warn "row $row is out of range for listmodel"
    return false
  end

  try
    m.setters[role](m.values, value(val), row)
    return true
  catch e
    rolename = rolenames(m)[role]
    if e isa ListModelFunctionUndefined
      @warn "No setter for role $rolename"
    else
      @warn "Error $e when setting value at row $row for role $rolename"
    end
    return false
  end
end

@cxxdereference function append_list(m::ListModelData, args::QVariantList)
  try
    push!(m.values, m.constructor((value(x) for x in args)...))
  catch e
    @error "Error $(typeof(e)) when appending value to listmodel."
  end
end

function remove(m::ListModelData, row::Integer)
  if row ∉ axes(m.values,1)
    @warn "row $row is out of range for listmodel"
    return
  end
  deleteat!(m.values, row)
end

function move(m::ListModelData, from::Integer, to::Integer, nb::Integer)
  @assert from < to

  # Save elements to mov
  removed_elems = m.values[from:from+nb-1]
  # Shift elements that remain
  m.values[from:to-1] .= m.values[(from:to-1).+nb]
  # Place saved elements in to block
  m.values[to:to+nb-1] .= removed_elems

  return
end

clear(m::ListModelData) = empty!(m.values)
Base.push!(m::ListModelData, val) = push!(m.values, val)

"""
    function ListModel(items::AbstractVector, addroles::Bool = true)

Constructor for a ListModel. The `ListModel` type allows using data in QML views such as
`ListView` and `Repeater`, providing a two-way synchronization of the data. A ListModel is
constructed from a 1D Julia array. To use the model from QML, it can be exposed as a context
attribute.

A constructor (the `eltype`) and setter and getter "roles" based on the `fieldnames` of the
`eltype` will be automatically created if `addroles` is `true`.

If new elements need to be constructed from QML, a constructor can also be provided, using
the [`setconstructor`](@ref) method. QML can pass a list of arguments to constructors.

In Qt, each of the elements of a model has a series of roles, available as properties in the
delegate that is used to display each item. The roles can be added using the
[`addrole`](@ref) function.

```jldoctest
julia> using QML

julia> using Qt5QuickControls_jll

julia> mutable struct Fruit
          name::String
          cost::Float64
        end

julia> fruits = ListModel([Fruit("apple", 1.0), Fruit("orange", 2.0)]);

julia> mktempdir() do folder
          path = joinpath(folder, "main.qml")
          write(path, \"""
          import QtQuick 2.0
          import QtQuick.Controls 1.0
          import QtQuick.Layouts 1.0
          ApplicationWindow {
            visible: true
            ListView {
              model: fruits
              anchors.fill: parent
              delegate:
                Row {
                  Text {
                    text: name
                  }
                  Button {
                    text: "Sale"
                    onClicked: cost = cost / 2
                  }
                  Button {
                    text: "Duplicate"
                    onClicked: fruits.append([name, cost])
                  }
                  Timer {
                    running: true
                    onTriggered: Qt.quit()
                  }
                }
              }
            }
          \""")
          loadqml(path; fruits = fruits)
          exec()
        end
```
"""
function ListModel(a::AbstractVector{T}, addroles=true) where {T}
  data = ListModelData(a)
  if addroles
    empty!(data.roles)
    empty!(data.getters)
    empty!(data.setters)
    if !isabstracttype(T) && !isempty(fieldnames(T))
      for fname in fieldnames(T)
        push!(data.roles, string(fname))
        push!(data.getters, (x) -> getfield(x, fname))
        push!(data.setters, (array, value, index) -> setproperty!(array[index], fname, value))
      end
      data.constructor = T
    else
      push!(data.roles, "text")
      push!(data.getters, string)
      push!(data.setters, defaultsetter)
    end
  end

  return ListModel(data)
end

"""
    function roles(model::ListModel)

See all roles defined for a [`ListModel`](@ref). See the example for [`addrole`](@ref).
"""
roles(lm::ListModel) = rolenames(get_julia_data(lm))

"""
    function addrole(model::ListModel, name::String, getter, [setter])

Add your own `getter` (and optionally, `setter`) functions to a [`ListModel`](@ref) for use
by QML. `setter` is optional, and if it is not provided the role will be read-only. `getter`
will process an item before it is returned. The arguments of `setter` will be
`collection, new_value, index` as in the standard `setindex!` function. If you would like to
see the roles defined for a list, use [`roles`](@ref). To remove a role, use
[`removerole`](@ref).

```jldoctest
julia> using QML

julia> using Qt5QuickControls_jll

julia> items = ["A", "B"];

julia> array_model = ListModel(items, false);

julia> addrole(array_model, "item", identity, setindex!)

julia> roles(array_model)
1-element QML.QStringListAllocated:
 "item"

julia> mktempdir() do folder
          path = joinpath(folder, "main.qml")
          write(path, \"""
          import QtQuick 2.0
          import QtQuick.Controls 1.0
          import QtQuick.Layouts 1.0
          ApplicationWindow {
            visible: true
            ListView {
              model: array_model
              anchors.fill: parent
              delegate: TextField {
                placeholderText: item
                onTextChanged: item = text;
              }
            }
            Timer {
              running: true
              onTriggered: Qt.quit()
            }
          }
          \""")
          loadqml(path; array_model = array_model)
          exec()
        end

julia> removerole(array_model, "item")
```
"""
function addrole(lm::ListModel, name, getter, setter=defaultsetter)
  m = get_julia_data(lm)
  if name ∈ rolenames(m)
    @error "Role $name exists, aborting add"
    return
  end

  if !m.customroles
    empty!(m.roles)
    empty!(m.getters)
    empty!(m.setters)
    m.customroles = true
  end

  push!(m.roles, name)
  push!(m.getters, getter)
  push!(m.setters, setter)

  emit_roles_changed(lm)

  return
end

function setrole(lm::ListModel, idx::Integer, name, getter, setter=defaultsetter)
  m = get_julia_data(lm)
  if idx ∉ axes(rolenames(m),1)
    @error "Listmodel index $idx is out of range, aborting setrole"
  end

  if name ∈ rolenames(m) && rolenames(m)[idx] != name
    @error "Role $name exists, aborting setrole"
    return
  end

  m.getters[idx] = getter
  m.setters[idx] = setter

  if rolenames(m)[idx] == name
    emit_data_changed(lm, 0, length(lm), StdVector(Int32[idx]))
  else
    m.roles[idx] = name
    emit_roles_changed(lm)
  end
end

function removerole(lm::ListModel, idx::Integer)
  m = get_julia_data(lm)
  if idx ∉ axes(rolenames(m),1)
    @error "Request to delete non-existing role $idx, aborting"
    return
  end

  deleteat!(m.roles, idx)
  deleteat!(m.getters, idx)
  deleteat!(m.setters, idx)

  @assert length(m.roles) == length(m.getters)

  emit_roles_changed(lm)
end

"""
    function removerole(model::ListModel, name::AbstractString)

Remove one of the [`roles`](@ref) from a [`ListModel`](@ref). See the example for
[`addrole`](@ref).
"""
function removerole(lm::ListModel, name::AbstractString)
  m = get_julia_data(lm)
  idx = findfirst(isequal(name), m.roles)

  if isnothing(idx)
    @error "Request to delete non-existing role $name, aborting"
    return
  end
  removerole(lm,idx)
end

"""
    function setconstructor(model::ListModel, constructor)

Add a constructor to a [`ListModel`](@ref). The `constructor` will process `append`ed items
before they are added. Note that you can simply pass a list of arguments from QML,
and they will be interpret in Julia as positional arguments.

```jldoctest
julia> using QML

julia> using Qt5QuickControls_jll

julia> items = ["A", "B"];

julia> array_model = ListModel(items, false);

julia> setconstructor(array_model, uppercase);

julia> mktempdir() do folder
          path = joinpath(folder, "main.qml")
          write(path, \"""
          import QtQuick 2.0
          import QtQuick.Controls 1.0
          import QtQuick.Layouts 1.0
          ApplicationWindow {
            visible: true
            Button {
              text: "Add C"
              onClicked: array_model.append(["c"])
            }
            Timer {
              running: true
              onTriggered: Qt.quit()
            }
          }
          \""")
          loadqml(path; array_model = array_model)
          exec()
        end
```
"""
function setconstructor(lm::ListModel, constructor)
  get_julia_data(lm).constructor = constructor
end

# ListModel Julia interface
Base.getindex(lm::ListModel, idx::Int) = get_julia_data(lm).values[idx]
function Base.setindex!(lm::ListModel, value, idx::Int)
  lmdata = get_julia_data(lm)
  lmdata.values[idx] = value
  emit_data_changed(lm, idx-1, 1, StdVector{Int32}())
end
Base.push!(lm::ListModel, val) = push_back(lm, val)
Base.size(lm::ListModel) = Base.size(get_julia_data(lm).values)
Base.length(lm::ListModel) = length(get_julia_data(lm).values)
Base.delete!(lm::ListModel, i) = remove(lm, i-1)

function force_model_update(lm::ListModel)
  lmdata = get_julia_data(lm)
  emit_data_changed(lm, 0, length(lm), StdVector{Int32}())
end

global _async_timer

# Stop the async loop (called on quit from C++)
function _stoptimer()
  if !isdefined(QML, :_async_timer)
    return
  end
  global _async_timer
  if isopen(_async_timer)
    close(_async_timer)
  end
end

function exec_async()
  global _async_timer = Timer((t) -> process_events(), 0.015; interval=0.015)
  return
end

include("docs.jl")
include("runexamples.jl")

end
