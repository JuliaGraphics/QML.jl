using Test
using QML

# absolute path in case working dir is overridden
qml_file = joinpath(dirname(@__FILE__), "qml", "listviews.qml")

julia_array = ["A", 1, 2.2]

function testfail(message)
  println(message)
  exit(1)
end

myrole2(x::AbstractString) = lowercase(x)
myrole2(x::Number) = Int(round(x))
decorated2(x) = "---" * string(x) * "---"

array_model = ListModel(julia_array)
addrole(array_model, "string", string)
array_model2 = ListModel(julia_array)
addrole(array_model2, "myrole", myrole2, setindex!)
addrole(array_model2, "decorated", decorated2)
setconstructor(array_model2, identity)

mutable struct TableItem
  a::Int32
  b::Int32
  c::Int32
end

tableitems = [TableItem(1,2,3), TableItem(4,5,6)]
tablemodel = ListModel(tableitems)

removerole_b() = removerole(tablemodel, 2)
removerole_c() = removerole(tablemodel, "c")
setrole_a() = setrole(tablemodel, 1, "abc", (x::TableItem) -> x.a*x.b*x.c)

@qmlfunction testfail removerole_b removerole_c setrole_a
loadqml(qml_file, array_model=array_model, array_model2=array_model2, tablemodel=tablemodel)

exec()

@show julia_array

@test julia_array[1] == "TEST"
@test size(array_model) == (3,)
@test array_model[2] == 1
array_model[1] = 42
@test array_model[1] == 42
@test julia_array[1] == 42
push!(array_model, "Test2")
@test array_model[4] == "Test2"
@test julia_array[end] == "Test2"
@test length(julia_array) == 4
@test length(array_model) == 4
delete!(array_model,3)
@test length(julia_array) == 3
@test length(array_model) == 3
@test julia_array[3] == "Test2"
