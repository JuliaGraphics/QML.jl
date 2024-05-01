module QML

export QVariant, QString, QUrl
export QQmlContext, root_context, loadqml, watchqml, qt_prefix_path, set_source, engine, QByteArray, QQmlComponent, set_data, create, QQuickItem, content_item, QTimer, context_property, emit, JuliaDisplay, JuliaCanvas, qmlcontext, init_qmlapplicationengine, init_qmlengine, init_qquickview, exec, exec_async, QVariantMap
export JuliaPropertyMap
export QStringList, QVariantList
export JuliaItemModel, addrole!, roles, roleindex, setgetter!, setsetter!, setheadergetter!, setheadersetter!
export QPainter, device, width, height, logicalDpiX, logicalDpiY, QQuickWindow, effectiveDevicePixelRatio, window, JuliaPaintedItem
export @emit, @qmlfunction, qmlfunction, QQmlPropertyMap
export set_context_property
export QUrlFromLocalFile
export qputenv, qgetenv, qunsetenv

# TODO: Document: init_qmlapplicationengine
# TODO: Document painter: device, effectiveDevicePixelRatio, height, JuliaCanvas, JuliaPaintedItem, logicalDpiX, logicalDpiY, width, window

if haskey(ENV, "WAYLAND_DISPLAY") || get(ENV, "XDG_SESSION_TYPE", "") == "wayland"
  # loading this automatially on Wayland ensures that applications run natively on Wayland without user intervention
  using Qt6Wayland_jll
end

import jlqml_jll

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

@readmodule jlqml_jll.get_libjlqml_path :define_julia_module Libdl.RTLD_GLOBAL
@wraptypes

const QStringList = QList{QString}

# Make sure functions accepting a QString argument also accept a Julia string
CxxWrap.argument_overloads(::Type{<:QString}) = [QString,String]

@wrapfunctions

# Protect items stored in a QML context from GC
global __context_gc_protection = Dict{ConstCxxPtr{QQmlContext}, Vector{Any}}()

# Clear GC protection list when the context is destroyed
function on_context_destroyed(ctx)
  ctx_cast = ConstCxxPtr{QQmlContext}(ctx[])
  delete!(__context_gc_protection, ctx_cast)
end

function context_gc_protect(ctx::ConstCxxPtr{QQmlContext}, value)
  if !haskey(__context_gc_protection, ctx)
    __context_gc_protection[ctx] = Any[]
    connect_destroyed_signal(ctx[], on_context_destroyed)
  end
  push!(__context_gc_protection[ctx], value)
  return
end

@cxxdereference function set_context_property(ctx::QQmlContext, name, value::QObject)
  context_gc_protect(ConstCxxPtr(ctx), value)
  _set_context_property(ctx, QString(name), CxxPtr(value))
  return
end
@cxxdereference function set_context_property(ctx::QQmlContext, name, value)
  context_gc_protect(ConstCxxPtr(ctx), value)
  _set_context_property(ctx, QString(name), QVariant(value))
  return
end

function load_qml(qmlfilename, engine)
  ctx = root_context(CxxRef(engine))
  if !load_into_engine(engine, QString(qmlfilename))
    cleanup()
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
  try
    return load_qml(qmlfilename, qml_engine)
  catch
    cleanup()
    rethrow()
  end
end

function watchqml(engine::CxxPtr{QQmlApplicationEngine}, qmlfile)
  function clearcache(path)
    rootobject = first(QML.rootObjects(engine))
    QML.deleteLater(rootobject)
    QML.clearComponentCache(engine)
    QML.load_into_engine(engine, path)
  end

  watcher = QML.QFileSystemWatcher(engine)
  QML.addPath(watcher, qmlfile)
  QML.connect_file_changed_signal(watcher, clearcache)
end

function watchqml(qview::CxxPtr{QQuickView}, qmlfile)
  engine = QML.engine(qview)

  function clearcache(path)
    QML.clearComponentCache(engine)
    set_source(qview, QUrlFromLocalFile(path))
  end
  
  watcher = QML.QFileSystemWatcher(engine)
  QML.addPath(watcher, qmlfile)
  QML.connect_file_changed_signal(watcher, clearcache)
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

# Persistent C++ - compatible storage of the command line arguments, passed to the QGuiApplication constructor
mutable struct ArgcArgv
  argv
  argc::Ref{Cint}

  function ArgcArgv(args::Vector{String})
    argv = Base.cconvert(CxxPtr{CxxPtr{CxxChar}}, args)
    argc = length(args)
    return new(argv, argc)
  end
end

getargv(a::ArgcArgv) = Base.unsafe_convert(CxxPtr{CxxPtr{CxxChar}}, a.argv)

# Keeps track of the unique QGuiApplication instance, which is created on application init.
# We need to keep this in Julia, because the correct order of destruction of global instances
# is only preserved if this object is destroyed when all finalizers run. Otherwise, Qt thread
# local data will be destroyed before the main thread exits.
@static if VERSION >= v"1.8"
  global ARGV::ArgcArgv
  global APPLICATION::QGuiApplication
else
  global ARGV
  global APPLICATION
end

function __init__()
  @initcxx

  @require GLMakie="e9467ef8-e4e7-5192-8a1a-b1aee30e663a" include(joinpath(@__DIR__, "makie_support.jl"))

  loadqmljll(jlqml_jll.Qt6Declarative_jll)
  @require Qt65Compat_jll="f5784262-74e5-52be-b835-f3e8a3cf8710" @eval loadqmljll(Qt65Compat_jll)

  global ARGV = ArgcArgv([Base.julia_cmd()[1], ARGS...])
  global APPLICATION = QGuiApplication(ARGV.argc, getargv(ARGV))
end

# QString
QString(s::String) = fromStdWString(StdWString(s))
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

# QByteArray
Base.convert(::Type{QByteArray}, s::AbstractString) = QByteArray(s)
@cxxdereference Base.print(io::IO, x::QByteArray) = print(io, to_string(x))
@cxxdereference Base.show(io::IO, x::QByteArray) = Base.show(io, to_string(x))

# QVariant
const QVariantList = QList{QVariant}
const QVariantMap = QMap{QString,QVariant}

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

# QList
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

# QHash
Base.isempty(h::QHash) = empty(h)
Base.length(h::QHash) = Int(cppsize(h))
Base.haskey(h::QHash, key) = QML.contains(h, key)
function Base.getindex(h::QHash{K,V}, key) where {K,V}
  if !haskey(h,key)
    throw(KeyError(key))
  end
  return cppgetindex(h, convert(K,key))[]
end
Base.setindex!(h::QHash{K,V}, val, key) where {K,V} = cppsetindex!(h, convert(V,val), convert(K,key))
Base.empty!(h::QHash) = clear(h)
Base.delete!(h::QHash{K,V}, key) where {K,V} = remove(h, convert(K,key))
Base.:(==)(a::QHashIterator, b::QHashIterator) = iteratorisequal(a,b)
function _qhash_iteration_tuple(h::QHash, state::QHashIterator)
  if state == iteratorend(h)
    return nothing
  end
  return (iteratorkey(state) => iteratorvalue(state), state)
end
Base.iterate(h::QHash) = _qhash_iteration_tuple(h, iteratorbegin(h))
Base.iterate(h::QHash, state::QHashIterator) = _qhash_iteration_tuple(h, iteratornext(state))
Base.values(h::QHash) = QML.values(h)
Base.keys(h::QHash) = QML.keys(h)

# QMap
Base.isempty(h::QMap) = empty(h)
Base.length(h::QMap) = Int(cppsize(h))
Base.haskey(h::QMap, key) = QML.contains(h, key)
function Base.getindex(h::QMap{K,V}, key) where {K,V}
  if !haskey(h,key)
    throw(KeyError(key))
  end
  return cppgetindex(h, convert(K,key))[]
end
Base.setindex!(h::QMap{K,V}, val, key) where {K,V} = cppsetindex!(h, convert(V,val), convert(K,key))
Base.empty!(h::QMap) = clear(h)
Base.delete!(h::QMap{K,V}, key) where {K,V} = remove(h, convert(K,key))
Base.:(==)(a::QMapIterator, b::QMapIterator) = iteratorisequal(a,b)
function _qmap_iteration_tuple(h::QMap, state::QMapIterator)
  if state == iteratorend(h)
    return nothing
  end
  return (iteratorkey(state) => iteratorvalue(state), state)
end
Base.iterate(h::QMap) = _qmap_iteration_tuple(h, iteratorbegin(h))
Base.iterate(h::QMap, state::QMapIterator) = _qmap_iteration_tuple(h, iteratornext(state))
Base.values(h::QMap) = QML.values(h)
Base.keys(h::QMap) = QML.keys(h)

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
      for k in Base.keys(jpm.dict)
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

julia> using Observables: Observable, on

julia> output = Observable(0.0);

julia> on(println, output);

julia> mktempdir() do folder
         path = joinpath(folder, "main.qml")
         write(path, \"""
         import QtQuick
         import QtQuick.Controls
         ApplicationWindow {
           visible: true
           Slider {
             onValueChanged: {
               observables.output = value;
             }
           }
           Timer {
             running: true; repeat: false
             onTriggered: Qt.exit(0)
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

const _queued_properties = []

# Functor to update a QML property when an Observable is changed in Julia
struct QmlPropertyUpdater
  propertymap::QQmlPropertyMap
  key::String
  active::Bool
end
function (updater::QmlPropertyUpdater)(x)
  if Base.current_task() != Base.roottask
    push!(_queued_properties, (updater, x))
    return
  end
  updater.propertymap[updater.key] = x
end

setactive!(::Any,::Bool) = nothing
setactive!(updater::QmlPropertyUpdater, active::Bool) = (updater.active = active)

Base.getindex(jpm::JuliaPropertyMap, k::AbstractString) = jpm.dict[k]
Base.get(jpm::JuliaPropertyMap, k::AbstractString, def) = get(jpm.dict, k, def)

function Base.delete!(jpm::JuliaPropertyMap, k::AbstractString)
  storedvalue = jpm.dict[k]
  if storedvalue isa Observable
    for (_,observer) in filter(x -> x[2] isa QmlPropertyUpdater, Observables.listeners(storedvalue))
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
  context_gc_protect(ConstCxxPtr(ctx), jpm) # This is to protect the jpm object from GC
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

julia> duplicate(value) = @emit duplicateSignal(value);

julia> @qmlfunction duplicate

julia> mktempdir() do folder
          path = joinpath(folder, "main.qml")
          write(path, \"""
          import QtQuick
          import QtQuick.Controls
          import QtQuick.Layouts
          import org.julialang
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
                  running: true; repeat: false
                  onTriggered: Qt.exit(0)
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

julia> greet() = "Hello, World!";

julia> @qmlfunction greet

julia> mktempdir() do folder
          path = joinpath(folder, "main.qml")
          write(path, \"""
          import org.julialang
          import QtQuick
          import QtQuick.Controls
          ApplicationWindow {
            visible: true
            Text {
              text: Julia.greet()
            }
            Timer {
              running: true; repeat: false
              onTriggered: Qt.exit(0)
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

include("itemmodel.jl")

global _async_timer

function exec_async()
  newrepl = @async Base.run_main_repl(true,true,true,true,true)
  while !istaskdone(newrepl)
      for (updater, x) in _queued_properties
        updater.propertymap[updater.key] = x
      end
      empty!(_queued_properties)
      process_events()
      sleep(0.015)
  end
  QML.quit(QML.get_qmlengine())
  QML.quit()
  QML.cleanup()
  QML.process_events()
  return
end

include("docs.jl")
include("runexamples.jl")

end
