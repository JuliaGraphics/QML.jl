using BinDeps
using CxxWrap

const QML_JL_VERSION = v"0.4.3"

QT_ROOT = get(ENV, "QT_ROOT", "")

@static if is_windows()
  build_on_windows = false
  # prefer building if requested
  if get(ENV, "BUILD_ON_WINDOWS", "") != ""
    build_on_windows = true
    saved_defaults = deepcopy(BinDeps.defaults)
    empty!(BinDeps.defaults)
    append!(BinDeps.defaults, [BuildProcess])
  end
end

@BinDeps.setup

jlcxx_dir = Pkg.dir("CxxWrap","deps","usr","share","cmake")

qmlwrap = library_dependency("qmlwrap", aliases=["libqmlwrap"])

used_homebrew = false
if QT_ROOT == ""
  if is_apple()
    std_hb_root = "/usr/local/opt/qt"
    if(!isdir(std_hb_root))
      try
        using Homebrew
      catch
        error("Homebrew package not installed, please run Pkg.add(\"Homebrew\")")
      end
      if !Homebrew.installed("qt")
        Homebrew.add("qt")
      end
      if !Homebrew.installed("cmake")
        Homebrew.add("cmake")
      end
      used_homebrew = true
      QT_ROOT = joinpath(Homebrew.prefix(), "opt", "qt")
    else
      QT_ROOT = std_hb_root
    end
  end

  if is_linux()
    try
      run(pipeline(`cmake --version`, stdout=DevNull, stderr=DevNull))
      try
        run(pipeline(`qmake-qt5 --version`, stdout=DevNull, stderr=DevNull))
      catch
        run(pipeline(`qmake --version`, stdout=DevNull, stderr=DevNull))
      end
      run(pipeline(`qmlscene $(joinpath(dirname(@__FILE__), "imports.qml"))`, stdout=DevNull, stderr=DevNull))
    catch
      println("Installing Qt and cmake...")

      function printrun(cmd)
        println("Running install command, if this fails please run manually:\n$cmd")
        run(cmd)
      end

      if BinDeps.can_use(AptGet)
        printrun(`sudo apt-get install cmake cmake-data qtdeclarative5-dev qml-module-qtquick-controls qml-module-qtquick-dialogs qmlscene qt5-default`)
      elseif BinDeps.can_use(Pacman)
        printrun(`sudo pacman -S --needed qt5-quickcontrols2`)
      elseif BinDeps.can_use(Yum)
        printrun(`sudo yum install cmake qt5-qtbase-devel qt5-qtquickcontrols qt5-qtquickcontrols2-devel`)
      end
    end
  end
end

prefix=joinpath(BinDeps.depsdir(qmlwrap),"usr")
qmlwrap_srcdir = joinpath(BinDeps.depsdir(qmlwrap),"src","qmlwrap")
qmlwrap_builddir = joinpath(BinDeps.depsdir(qmlwrap),"builds","qmlwrap")
lib_prefix = @static is_windows() ? "" : "lib"
lib_suffix = @static is_windows() ? "dll" : (@static is_apple() ? "dylib" : "so")

makeopts = ["--", "-j", "$(Sys.CPU_CORES+2)"]

# Set generator if on windows
genopt = "Unix Makefiles"
@static if is_windows()
  if isdir(prefix)
    rm(prefix, recursive=true)
  end
  if get(ENV, "MSYSTEM", "") == ""
    makeopts = "--"
    if Sys.WORD_SIZE == 64
      genopt = "Visual Studio 14 2015 Win64"
    else
      genopt = "Visual Studio 14 2015"
    end
    if QT_ROOT == ""
      QT_ROOT = "C:\\Qt\\5.7"
    end
    QT_ROOT = joinpath(QT_ROOT, Sys.WORD_SIZE == 64 ? "msvc2015_64" : "msvc2015")
  else
    lib_prefix = "lib" #Makefiles on windows do keep the lib prefix
  end
end

cmake_prefix = QT_ROOT
if(cmake_prefix != "")
  println("Using Qt from $cmake_prefix")
else
  println("Using system Qt")
end

cmake_prefix *= (cmake_prefix == "" ? "" : ";")*jlcxx_dir

build_type = get(ENV, "CXXWRAP_BUILD_TYPE", "Release")

qml_steps = @build_steps begin
	`cmake -G "$genopt" -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_BUILD_TYPE="$build_type" -DCMAKE_PREFIX_PATH="$cmake_prefix" -DCMAKE_PROGRAM_PATH="$JULIA_HOME" $qmlwrap_srcdir`
	`cmake --build . --config $build_type --target install $makeopts`
end

# If built, always run cmake, in case the code changed
if isdir(qmlwrap_builddir)
  BinDeps.run(@build_steps begin
    ChangeDirectory(qmlwrap_builddir)
    qml_steps
  end)
end

provides(BuildProcess,
  (@build_steps begin
    CreateDirectory(qmlwrap_builddir)
    @build_steps begin
      ChangeDirectory(qmlwrap_builddir)
      FileRule(joinpath(prefix,"lib", "$(lib_prefix)qmlwrap.$lib_suffix"),qml_steps)
    end
  end),qmlwrap)

deps = [qmlwrap]
@static if is_windows()
  shortversion = "$(VERSION.major).$(VERSION.minor)"
  zipfilename = "QML-julia-$(shortversion)-win$(Sys.WORD_SIZE).zip"
  archname = Sys.WORD_SIZE == 64 ? "x64" : "x86"
  pkgverstring = string(QML_JL_VERSION)
  if endswith(pkgverstring,"+")
    bin_uri = URI("https://ci.appveyor.com/api/projects/barche/qml-jl/artifacts/$(zipfilename)?job=Environment%3a+JULIA_URL%3dhttps%3a%2f%2fjulialang-s3.julialang.org%2fbin%2fwinnt%2f$(archname)%2f$(shortversion)%2fjulia-$(shortversion)-latest-win$(Sys.WORD_SIZE).exe%2c+BUILD_ON_WINDOWS%3d1")
  else
    bin_uri = URI("https://github.com/barche/QML.jl/releases/download/v$(pkgverstring)/QMLv$(pkgverstring)-julia-$(VERSION.major).$(VERSION.minor)-win$(Sys.WORD_SIZE).zip")
  end
  provides(Binaries, Dict(bin_uri => deps), os = :Windows)
end

@BinDeps.install Dict([(:qmlwrap, :_l_qml_wrap)])

@static if is_windows()
  if build_on_windows
    empty!(BinDeps.defaults)
    append!(BinDeps.defaults, saved_defaults)
  end
end

if used_homebrew
  # Not sure why this is needed on homebrew Qt, but here goes:
  envfile_path = joinpath(dirname(@__FILE__), "env.jl")
  plugins_path = joinpath(QT_ROOT, "plugins")
  qml_path = joinpath(QT_ROOT, "qml")
  open(envfile_path, "w") do envfile
    println(envfile, "ENV[\"QT_PLUGIN_PATH\"] = \"$plugins_path\"")
    println(envfile, "ENV[\"QML2_IMPORT_PATH\"] = \"$qml_path\"")
  end
end

if get(ENV, "MSYSTEM", "") != ""
  println("Copying libs")
  ldd = Sys.WORD_SIZE == 32 ? "ntldd" : "ldd"
  msys_libdir = joinpath("/mingw"*string(Sys.WORD_SIZE), "bin")
  libdest = joinpath(prefix,"lib")
  collected_libs = Set()
  for (root, dirs, files) in walkdir(prefix)
    for file in files
      if endswith(file, ".dll") && !startswith(file,"Qt5")
        open(`$ldd $(joinpath(root, file))`) do f
          while !eof(f)
            line = readline(f)
            splitlibs = split(line)
            libname = splitlibs[1]
            libpath = splitlibs[3]
            if dirname(libpath) == msys_libdir && !startswith(libname, "Qt5")
              push!(collected_libs, libpath)
            end
          end
        end
      end
    end
  end
  for lib in collected_libs
    println("Copying lib $lib")
    run(`cp $lib $libdest`)
  end
  mingw_prefix = "/mingw"*string(Sys.WORD_SIZE)
  run(`cp -rf $(mingw_prefix)/share/qt5/qml/QtQ\* $(libdest)/`)
end
