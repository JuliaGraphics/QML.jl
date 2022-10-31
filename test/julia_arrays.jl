using Test
using QML
using Observables

# absolute path in case working dir is overridden
qml_file = joinpath(dirname(@__FILE__), "qml", "julia_arrays.qml")

move_array = collect(0:9)
resize_typed_array = collect(1:5)
insert_array = [1,2,4]
clear_array = [1.,2.]
int_array = [1,2,3]

arrays = JuliaPropertyMap(
  "julia_array" => ["A", 1, 2.2],
  "any_array" => Any[1,2,3],
  "int_array" => int_array,
  "ob_array" => Observable(int_array),
)

julia_array = arrays["julia_array"]

get_array() = julia_array

myrole(x::AbstractString) = lowercase(x)
myrole(x::Number) = Int(round(x))
decorated(x) = "---" * string(x) * "---"

array_model = JuliaItemModel(julia_array)
array_model2 = JuliaItemModel(julia_array)
move_model = JuliaItemModel(move_array)
resize_typed_model = JuliaItemModel(resize_typed_array)
insert_model = JuliaItemModel(insert_array)
clear_model = JuliaItemModel(clear_array)

addrole(array_model2, "myrole", myrole, setindex!)
addrole(array_model2, "decorated", decorated)
setconstructor(array_model2, identity)
setconstructor(insert_model, identity)

mutable struct ListElem
  a::String
  b::Int32
end

custom_list = [ListElem("a",1), ListElem("b", 2)]
custom_model = JuliaItemModel(custom_list)

roles = JuliaPropertyMap()
roles["myrole"] = roleindex(array_model2, "myrole")
roles["b"] = roleindex(custom_model, "b")

@qmlfunction get_array
loadqml(qml_file;
  arrays,
  array_model,
  array_model2,
  move_model,
  resize_typed_model,
  insert_model,
  clear_model,
  custom_model,
  roles)

arrays["ob_array"][] = [4,5,6]

# Run the application
exec()

@show julia_array
@show move_array

@test length(julia_array) == 5
@test julia_array[1] == "A"
@test julia_array[2] == "TEST2"
@test julia_array[3] == "Added"
@test julia_array[4] == 2
@test typeof(julia_array[4]) == Int32
@test julia_array[5] == 3
@test typeof(julia_array[5]) == Int32
@test move_array == [0,1,5,6,7,2,3,4,8,9]
@test typeof(move_array) == Array{Int,1}
@test resize_typed_array == [5,1,2,4]
@test typeof(resize_typed_array) == Array{Int,1}
@test insert_array == [1,2,3,4]
@test isempty(clear_array)

@test custom_list[2].b == 5
@test length(custom_list) == 3
@show custom_list
@test custom_list[3].a == "ten"
@test custom_list[3].b == 10

@test arrays["ob_array"][] == [7, 8, 9]