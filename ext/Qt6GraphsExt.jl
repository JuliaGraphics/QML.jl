module Qt6GraphsExt

using QML
using Qt6Graphs_jll

function __init__()
  QML.loadqmljll(Qt6Graphs_jll)
end

end
