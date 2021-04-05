using QML
#=
A simple gui. A set of diagrams can be selected with check boxes.
They should be displayed, when the button "Plot" is clicked.
Currently only an array with the numbers of the selected diagrams
will be printed.
=#

"""
Convert a floating point number with values of the checkboxes, encoded
as sum of potences of two into an array that contains the numbers of the
checkboxes, that are checked.
"""
function plot_diagram(param)
    plot_set = round(Int, param)
    a = Int64[]
    if plot_set >= 256; push!(a,8); plot_set-=256; end
    if plot_set >= 128; push!(a,8); plot_set-=128; end
    if plot_set >=  64; push!(a,7); plot_set-= 64; end
    if plot_set >=  32; push!(a,6); plot_set-= 32; end
    if plot_set >=  16; push!(a,5); plot_set-= 16; end
    if plot_set >=   8; push!(a,4); plot_set-=  8; end
    if plot_set >=   4; push!(a,3); plot_set-=  4; end
    if plot_set >=   2; push!(a,2); plot_set-=  2; end
    if plot_set >=   1; push!(a,1); plot_set-=  1; end
    # In the real application you would here call the plotting routine
    println(a)
    return 0
end

@qmlfunction plot_diagram

loadqml(joinpath(dirname(Base.source_path()), "qml", "checkboxes.qml"))
exec()

return
