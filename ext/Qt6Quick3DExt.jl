module Qt6Quick3DExt

using QML
using Qt6Quick3D_jll

function __init__()
  QML.loadqmljll(Qt6Quick3D_jll)
end

end
