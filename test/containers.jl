if isdefined(@__MODULE__, :LanguageServer)
  @info "Using VS Code workaround..."
  include("../src/QML.jl")
  using .QML
else
  using QML
end

using Test

let l = QML.QList{QString}()
  @test isempty(l)
  push!(l, "test")
  @test l[1] == "test"
  @test l[1] isa QString
  push!(l, "test")
  @test length(l) == 2
  l[2] = "test2"
  @test l[2] == "test2"
  deleteat!(l, 1)
  @test length(l) == 1
  @test l[end] == l[1] == "test2"
  empty!(l)
  @test length(l) == 0
  @test isempty(l)
end

let h = QML.QHash{Int32,QML.QByteArray}()
  @test isempty(h)
  h[1] = "test1"
  @test string(h[1]) == "test1"
  h[3] = "test3"
  for (k,v) in h
    @test string(v) == "test$k"
  end
  @test haskey(h,1)
  @test sort(keys(h)) == [1,3]
  vals = values(h)
  @test "test1" ∈ string.(vals)
  delete!(h,1)
  @test length(h) == 1
  empty!(h)
  @test_throws KeyError h[1]
  @test isempty(h)
end

let numbers = [1,2,3,4], model = JuliaItemModel(numbers)
  modeldata = QML.get_julia_data(model)
  @test QML.rowcount(modeldata) == 4
  @test QML.colcount(modeldata) == 1
  @test QML.value(QML.data(modeldata, QML.DisplayRole,3,1)) == "3"
  @test QML.setdata!(model, QVariant(5), QML.EditRole, 3, 1)
  @test QML.value(QML.data(modeldata, QML.DisplayRole,3,1)) == "5"
  @test QML.value(QML.headerdata(modeldata, 2, QML.Vertical, QML.DisplayRole)) == 2
  @test_logs (:warn,"Setting header data is not supported in this model") QML.setheaderdata!(model, 1, QML.Vertical, QVariant("One"), QML.EditRole)
end
