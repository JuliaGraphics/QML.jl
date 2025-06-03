module Qt65CompatExt

using QML
using Qt65Compat_jll

function __init__()
  QML.loadqmljll(Qt65Compat_jll)
end

end
