using Test
using QML

# absolute path in case working dir is overridden
qml_file = joinpath(dirname(@__FILE__), "qml", "tableview.qml")

nberrors = 0
nbtestspass = 0

refvalues = [
  [1 2; 3 4; 5 6],
  [1 2; 3 4; 5 6; 7 8],
  [1 2; 3 4; 9 10; 5 6; 7 8],
  [1 2; 42 43; 9 10; 5 6; 7 8],
  [9 10; 1 2; 42 43; 5 6; 7 8],
  [9 10; 5 6; 7 8],
  [9 10; 5 6; 7 8; 152 153],
  [9 10 7; 5 6 8; 7 8 9; 152 153 10],
  [11 9 10 7; 12 5 6 8; 13 7 8 9; 14 152 153 10],
  [11 42 10 7; 12 43 6 8; 13 44 8 9; 14 45 153 10],
  [11 7 42 10; 12 8 43 6; 13 9 44 8; 14 10 45 153],
  [11 7; 12 8; 13 9; 14 10],
]

struct Table{T} <: AbstractArray{T,2}
  rows::Vector{Vector{T}}

  Table{T}(v::Vector{Vector{T}}) where {T} = new(v)
  Table{T}(v::Vector{S}) where {T,S} = new([[convert(T,x)] for x in v])
  Table{T}(m::AbstractMatrix{S}) where {T,S} = new([[convert.(T,m[i,:])...] for i in axes(m,1)])
  
end
Table(v::Vector{Vector{T}}) where T = Table{T}(v)
Table(m::AbstractMatrix{T}) where T = Table{T}(m)

Base.size(t::Table) = (length(t.rows), length(t.rows[1]))
Base.IndexStyle(::Type{<:Table}) = IndexCartesian()
Base.getindex(t::Table, i::Integer, j::Integer) = t.rows[i][j]
Base.setindex!(t::Table, val, i::Integer, j::Integer) = t.rows[i][j] = val
Base.push!(t::Table, row) = push!(t.rows, row)
Base.deleteat!(t::Table, rows) = deleteat!(t.rows, rows)
function Base.similar(t::Table, ::Type{S}, dims::Dims) where {S}
  if length(dims) == 1
    return Vector{S}(undef, dims[1])
  end
  nrows, ncols = dims
  return Table([Vector{S}(undef, ncols) for i in 1:nrows])
end

julia_table = Table([[1,2], [3,4], [5,6]])

tablemodel = JuliaItemModel(julia_table)

function toarray(qvariantarray)
  nrows = length(qvariantarray)
  ncols = length(QML.value(qvariantarray[1]))
  result = Array{Int}(undef, nrows, ncols)
  for i in 1:nrows
    result[i,:] .= QML.value.(QML.value(qvariantarray[i]))
  end
  return result
end

function compare(expected::Number, obtained::Number)
  try
    @test expected == obtained
  catch e
    global nberrors += 1
  end
end

function compare(refidx::Number, obtained::AbstractArray)
  println("testing case $refidx")
  try
    @test refvalues[refidx] == toarray(obtained)
    @test refvalues[refidx] == values(tablemodel)
    global nbtestspass += 1
  catch e
    global nberrors += 1
  end
end

properties = JuliaPropertyMap()
properties["ticks"] = Int32(0)

@qmlfunction compare
loadqml(qml_file, tablemodel=tablemodel, properties=properties)

exec()

julia_table = values(tablemodel)

@test nberrors == 0
@test nbtestspass == 12