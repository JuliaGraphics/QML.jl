using Tar, jlqml_jll, CodecZlib

tarball = "undefined"

julia_version = "julia_version+$(Int(VERSION.major)).$(Int(VERSION.minor))"

for fname in readdir()
  if !startswith(fname, "jlqml.")
    continue
  end
  if occursin(julia_version,fname) && (
    (Sys.islinux() && occursin("linux", fname)) ||
    (Sys.isapple() && occursin("apple", fname)) ||
  (Sys.iswindows() && occursin("mingw32", fname)))
    global tarball = fname
  end
end

mv(jlqml_jll.artifact_dir, jlqml_jll.artifact_dir*"_")
mkdir(jlqml_jll.artifact_dir)

open(GzipDecompressorStream, tarball) do io
  Tar.extract(io, jlqml_jll.artifact_dir)
end
