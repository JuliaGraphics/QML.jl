struct ListModelFunctionUndefined <: Exception end
defaultconstructor(roles...) = throw(ListModelFunctionUndefined())

const RoleNames = QHash{Int32,QByteArray}
const FunctionCollection = Dict{Int32,Any}

# Hack to add numbers and roles
Base.:+(a::QML.ItemDataRole, b::Integer) = convert(Int32,a) + b
# Allow roles as keys in Dicts:
Base.trailing_zeros(role::ItemDataRole) = Base.trailing_zeros(convert(Int32,role))
Base.:(>>)(a::ItemDataRole, b::Int64) = convert(Int32, a) >> b
mutable struct ItemModelData{DataT}
  values::DataT
  roles::RoleNames
  getters::FunctionCollection
  setters::FunctionCollection
  constructor::Union{Function,DataType}
  headerdata::Function
  setheaderdata::Function

  function ItemModelData{DataT}(modeldata::DataT) where {DataT}
    newmodel = new(modeldata, RoleNames(), FunctionCollection(), FunctionCollection(), defaultconstructor, defaultheaderdata, defaultsetheaderdata!)
    setgetter!(newmodel, string, DisplayRole)
    return newmodel
  end
end

Base.values(itemmodel::JuliaItemModel) = get_julia_data(itemmodel).values
rowcount(m::ItemModelData) = Int32(Base.size(m.values,1))
colcount(m::ItemModelData) = Int32(Base.size(m.values,2))
rolenames(m::ItemModelData) = m.roles

function rolegetter(m::ItemModelData, role::Integer)
  @assert haskey(m.getters, role)
  return m.getters[role]
end

function isvalidindex(values, row, col)
  if row ∉ axes(values,1)
    @warn "row $row is out of range for listmodel"
    return false
  end
  if col ∉ axes(values,2)
    @warn "column $col is out of range for listmodel"
    return false
  end
  return true
end

function data(m::ItemModelData, role::Integer, row::Integer, col::Integer)
  if !isvalidindex(m.values, row, col)
    return QVariant()
  end
  rolefunc = rolegetter(m, role)
  return QVariant(rolefunc(m.values[row,col]))
end

# By default, we just return the column or row number as header data
defaultheaderdata(data, row_or_col, orientation, role) = QVariant(row_or_col)

headerdata(m::ItemModelData, row_or_col, orientation, role) = m.headerdata(m.values, row_or_col, orientation, role)

@cxxdereference function setdata!(itemmodel::JuliaItemModel, val::QVariant, role::Integer, row::Integer, col::Integer)
  m = get_julia_data(itemmodel)
  if !isvalidindex(m.values, row, col)
    return false
  end

  try
    m.setters[role](m.values, value(val), row, col)
    emit_data_changed(itemmodel, row, col, row, col)
    return true
  catch e
    rolename = rolenames(m)[role]
    if e isa KeyError
      @warn "No setter for role $rolename"
    else
      @warn "Error $e when setting value at row $row for role $rolename"
    end
    return false
  end
end

# By default, no header data is set
function defaultsetheaderdata!(data, row_or_col, orientation, value, role)
  @warn "Setting header data is not supported in this model"
  return
end

function setheaderdata!(itemmodel::JuliaItemModel, row_or_col, orientation, value, role)
  m = get_julia_data(itemmodel)
  m.setheaderdata(m.values, row_or_col, orientation, value, role)
  emit_header_data_changed(itemmodel, orientation, row_or_col, row_or_col)
end

Base.empty!(itemmodel::JuliaItemModel) = clear!(itemmodel)

function row_to_vector(m::ItemModelData, row::QVariantMap)
  ncols = colcount(m)
  rowvector = Vector{QVariant}(undef, ncols)
  for col in 1:colcount(m)
    colheader = string(value(headerdata(m, col, QML.Horizontal, QML.DisplayRole)))
    if contains(row, colheader)
      rowvector[col] = row[colheader]
    else
      return nothing
    end
  end

  return rowvector
end

@cxxdereference function append_row!(m::JuliaItemModel, row::QVariant)
  modeldata = get_julia_data(m)
  idx = rowcount(modeldata) + 1
  begin_insert_rows(m, idx, idx)
  append_row!(modeldata, value(row))
  end_insert_rows(m)
end

function append_row!(m::ItemModelData, row::QVariantMap)
  rowvec = row_to_vector(m, row)
  if !isnothing(rowvec)
    append_row!(m, rowvec)
  else
    newrow = deepcopy(colcount(m) == 1 ? m.values[end] : m.values[end,:])
    push!(m.values, newrow)
    for (rolename,val) in row
      roleidx = roleindex(m, string(rolename))
      rowidx = rowcount(m)
      m.setters[roleidx](m.values, value(val), rowidx, 1)
    end
  end
end

function append_row!(m::ItemModelData, row::AbstractVector{QVariant})
  push!(m.values, value.(row))
end

@cxxdereference function insert_row!(m::JuliaItemModel, rowidx, row::QVariant)
  modeldata = get_julia_data(m)
  begin_insert_rows(m, rowidx, rowidx)
  insert_row!(modeldata, rowidx, value(row))
  end_insert_rows(m)
end

function insert_row!(m::ItemModelData, rowidx, row::AbstractVector{QVariant})
  if length(row) == 1
    insert!(m.values, rowidx, row...)
    return
  end
  ValT = typeof(m.values)
  startidx = axes(m.values)[1][1]
  m.values = vcat(m.values[startidx:rowidx-1,:], ValT(value.(row)'), m.values[rowidx:end,:])
  return
end

function make_move_permutation(values, fromidx, toidx, nbitems, dim)
  permutation = collect(axes(values,dim))
  fromrange = fromidx:fromidx+nbitems-1  
  deleteat!(permutation, fromrange)
  for (i,x) in  enumerate(fromrange)
    insert!(permutation, toidx+i-1, x)
  end
  return permutation
end

@cxxdereference function move_rows!(m::JuliaItemModel, fromidx, toidx, nbrows)
  values = get_julia_data(m).values
  if !begin_move_rows(m, fromidx, toidx, nbrows)
    @warn "Move from index $fromidx to $toidx not possible on this model"
    return
  end
  permutation = make_move_permutation(values, fromidx, toidx, nbrows, 1)
  values .= values[permutation,:]
  end_move_rows(m)
end

@cxxdereference function remove_rows!(m::JuliaItemModel, rowidx, nrows)
  begin_remove_rows(m, rowidx, nrows)
  deleteat!(get_julia_data(m).values, rowidx:rowidx+nrows-1)
  end_remove_rows(m)
end

@cxxdereference function set_row!(m::JuliaItemModel, rowidx, row::QVariant)
  modeldata = get_julia_data(m)
  set_row!(modeldata, rowidx, value(row))
  emit_data_changed(m, rowidx, 1, rowidx, Base.size(modeldata.values,2))
end

function set_row!(modeldata::ItemModelData, rowidx, row::AbstractVector{QVariant})
  modeldata.values[rowidx,:] .= value.(row)
end

@cxxdereference function append_column!(m::JuliaItemModel, column::QVariant)
  modeldata = get_julia_data(m)
  idx = colcount(modeldata) + 1
  begin_insert_columns(m, idx, idx)
  append_column!(modeldata, value(column))
  end_insert_columns(m)
end

function append_column!(m::ItemModelData, column::AbstractVector{QVariant})
  ValT = typeof(m.values)
  m.values = hcat(m.values, ValT(value.(column)))
end

@cxxdereference function insert_column!(m::JuliaItemModel, columnidx, column::QVariant)
  modeldata = get_julia_data(m)
  begin_insert_columns(m, columnidx, columnidx)
  insert_column!(modeldata, columnidx, value(column))
  end_insert_columns(m)
end

function insert_column!(m::ItemModelData, columnidx, column::AbstractVector{QVariant})
  ValT = typeof(m.values)
  startidx = axes(m.values)[2][1]
  m.values = hcat(m.values[:,startidx:columnidx-1], ValT(value.(column)), m.values[:,columnidx:end])
  return
end

@cxxdereference function move_columns!(m::JuliaItemModel, fromidx, toidx, nbcolumns)
  values = get_julia_data(m).values
  if !begin_move_columns(m, fromidx, toidx, nbcolumns)
    @warn "Move from index $fromidx to $toidx not possible on this model"
    return
  end
  permutation = make_move_permutation(values, fromidx, toidx, nbcolumns, 2)
  values .= values[:, permutation]
  end_move_columns(m)
end

@cxxdereference function remove_columns!(itemmodel::JuliaItemModel, columnidx, ncolumns)
  begin_remove_columns(itemmodel, columnidx, ncolumns)
  m = get_julia_data(itemmodel)
  m.values = hcat(m.values[:,1:columnidx-1], m.values[:,(columnidx+ncolumns):end])
  end_remove_columns(itemmodel)
end

@cxxdereference function set_column!(m::JuliaItemModel, columnidx, column::QVariant)
  modeldata = get_julia_data(m)
  set_column!(modeldata, columnidx, value(column))
  emit_data_changed(m, 1, columnidx, Base.size(modeldata.values,1), columnidx)
end

function set_column!(modeldata::ItemModelData, columnidx, column::AbstractVector{QVariant})
  modeldata.values[:,columnidx] .= value.(column)
end

clear!(m::ItemModelData) = empty!(m.values)
@cxxdereference function clear!(itemmodel::JuliaItemModel)
  begin_reset_model(itemmodel)
  clear!(get_julia_data(itemmodel))
  end_reset_model(itemmodel)
end

Base.push!(m::ItemModelData, val) = push!(m.values, val)

"""
    function JuliaItemModel(items::AbstractVector, addroles::Bool = true)

Constructor for a JuliaItemModel. The `JuliaItemModel` type allows using data in QML views such as
`ListView` and `Repeater`, providing a two-way synchronization of the data. A JuliaItemModel is
constructed from a 1D Julia array. To use the model from QML, it can be exposed as a context
attribute.

A constructor (the `eltype`) and setter and getter "roles" based on the `fieldnames` of the
`eltype` will be automatically created if `addroles` is `true`.

If new elements need to be constructed from QML, a constructor can also be provided, using
the [`setconstructor`](@ref) method. QML can pass a list of arguments to constructors.

In Qt, each of the elements of a model has a series of roles, available as properties in the
delegate that is used to display each item. The roles can be added using the
[`addrole!`](@ref) function.

```jldoctest
julia> using QML

julia> mutable struct Fruit
          name::String
          cost::Float64
        end

julia> fruits = JuliaItemModel([Fruit("apple", 1.0), Fruit("orange", 2.0)]);

julia> mktempdir() do folder
          path = joinpath(folder, "main.qml")
          write(path, \"""
          import QtQuick
          import QtQuick.Controls
          import QtQuick.Layouts
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
function JuliaItemModel(a::DataT, addroles=true) where {DataT}
  modeldata = ItemModelData{DataT}(a)
  qtmodel = new_item_model(modeldata)
  modeldata.roles = default_role_names(qtmodel)
  if addroles
    T = eltype(a)
    if !isabstracttype(T) && !isempty(fieldnames(T))
      for fname in fieldnames(T)
        rolename = string(fname)
        getter(x) = getfield(x, fname)
        setter(array, value, row, col) = setproperty!(array[row, col], fname, value)
        addrole!(modeldata, rolename, getter, setter)
      end
      modeldata.constructor = T
    else
      setgetter!(modeldata, string, DisplayRole)
      setsetter!(modeldata, setindex!, EditRole)
    end
  end
  return qtmodel
end

"""
    function roles(model::JuliaItemModel)

See all roles defined for a [`JuliaItemModel`](@ref). See the example for [`addrole!`](@ref).
"""
roles(lm::JuliaItemModel) = rolenames(get_julia_data(lm))

hasrole(m::ItemModelData, rolename) = rolename ∈ values(m.roles)
hasrole(lm::JuliaItemModel, rolename) = hasrole(get_julia_data(lm), rolename)
function nextroleindex(roles)
  sortedkeys = sort(keys(roles))
  return max(UserRole,sortedkeys[end]+1)
end

function roleindex(m::ItemModelData, rolename)
  for (idx,val) in m.roles
    if string(val) == rolename
      return idx
    end
  end
  @warn "Role $rolename not found"
  return -1
end
roleindex(lm::JuliaItemModel, rolename) = roleindex(get_julia_data(lm), rolename)

setgetter!(lm::JuliaItemModel, getter, roleidx) = setgetter!(get_julia_data(lm), getter, roleidx)
function setgetter!(m::ItemModelData, getter, roleidx)
  m.getters[roleidx] = getter
end

setsetter!(lm::JuliaItemModel, setter, roleidx) = setsetter!(get_julia_data(lm), setter, roleidx)
function setsetter!(m::ItemModelData, setter, roleidx)
  m.setters[roleidx] = setter
end

"""
    function addrole!(model::JuliaItemModel, name::String, getter, [setter])

Add your own `getter` (and optionally, `setter`) functions to a [`JuliaItemModel`](@ref) for use
by QML. `setter` is optional, and if it is not provided the role will be read-only. `getter`
will process an item before it is returned. The arguments of `setter` will be
`collection, new_value, index` as in the standard `setindex!` function. If you would like to
see the roles defined for a list, use [`roles`](@ref).

```jldoctest
julia> using QML

julia> items = ["A", "B"];

julia> array_model = JuliaItemModel(items, false);

julia> addrole!(array_model, "item", identity, setindex!)

julia> roles(array_model)
1-element QML.QStringListAllocated:
 "item"

julia> mktempdir() do folder
          path = joinpath(folder, "main.qml")
          write(path, \"""
          import QtQuick
          import QtQuick.Controls
          import QtQuick.Layouts
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
```
"""
addrole!(lm::JuliaItemModel, name, getter, setter=nothing) = addrole!(get_julia_data(lm), name, getter, setter)
function addrole!(m::ItemModelData, name, getter, setter)
  if hasrole(m, name)
    @error "Role $name exists, aborting add"
    return
  end

  roleidx = nextroleindex(m.roles)

  m.roles[roleidx] = name
  setgetter!(m, getter, roleidx)
  if !isnothing(setter)
    setsetter!(m, setter, roleidx)
  end

  return
end


"""
    function setconstructor(model::JuliaItemModel, constructor)

Add a constructor to a [`JuliaItemModel`](@ref). The `constructor` will process `append`ed items
before they are added. Note that you can simply pass a list of arguments from QML,
and they will be interpret in Julia as positional arguments.

```jldoctest
julia> using QML

julia> items = ["A", "B"];

julia> array_model = JuliaItemModel(items, false);

julia> setconstructor(array_model, uppercase);

julia> mktempdir() do folder
          path = joinpath(folder, "main.qml")
          write(path, \"""
          import QtQuick
          import QtQuick.Controls
          import QtQuick.Layouts
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
function setconstructor(lm::JuliaItemModel, constructor)
  get_julia_data(lm).constructor = constructor
end

# JuliaItemModel Julia interface
Base.getindex(lm::JuliaItemModel, idx::Int) = get_julia_data(lm).values[idx]
function Base.setindex!(lm::JuliaItemModel, value, row, col=1)
  lmdata = get_julia_data(lm)
  lmdata.values[row, col] = value
  emit_data_changed(lm, row, col, row, col)
end
function Base.push!(lm::JuliaItemModel, val)
  m = get_julia_data(lm)
  idx = rowcount(m) + 1
  begin_insert_rows(lm, idx, idx)
  push!(m.values, val)
  end_insert_rows(lm)
end
function Base.size(lm::JuliaItemModel)
  modeldata = get_julia_data(lm)
  if colcount(modeldata) == 1
    return (rowcount(modeldata),)
  end
  return (rowcount(modeldata), colcount(modeldata))
end
Base.length(lm::JuliaItemModel) = length(get_julia_data(lm).values)
Base.delete!(lm::JuliaItemModel, i) = remove_rows!(lm, i, 1)

function force_model_update(lm::JuliaItemModel)
  begin_reset_model(lm)
  end_reset_model(lm)
end
