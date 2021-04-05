using QML

function singlefile(uri)
  uri_s = QString(uri)
  if isempty(uri_s)
    println("multiple files were selected")
    return
  end
  println("selected single file $uri_s")
end

function multifile(uri_list)
  println("selected paths:")
  for u in uri_list
    f = QString(u)[8:end]
    println("$f", isfile(f) ? " (file)" : "")
  end
end

@qmlfunction singlefile multifile

loadqml(joinpath(dirname(Base.source_path()), "qml", "filedialog.qml"))
exec()