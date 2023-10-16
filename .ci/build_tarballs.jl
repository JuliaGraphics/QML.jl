# Adapted from the Yggdrasil build script
# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg, TOML
import LibGit2, Downloads

# See https://github.com/JuliaLang/Pkg.jl/issues/2942
# Once this Pkg issue is resolved, this must be removed
uuid = Base.UUID("a83860b7-747b-57cf-bf1f-3e79990d037f")
delete!(Pkg.Types.get_last_stdlibs(v"1.6.3"), uuid)

function getversion(cmakefile)
    a = b = c = 0
    for l in readlines(cmakefile)
        if startswith(l, "set(JlQML_VERSION")
            a, b, c = parse.(Int, split(replace(split(l)[end], ")" => ""),'.'))
        end
    end
    return VersionNumber(a, b, c)
end

name = "jlqml"

jlqml_repo = LibGit2.clone("https://github.com/JuliaGraphics/jlqml.git", name)
head_commit = string(LibGit2.head_oid(jlqml_repo))
yggdrasil_buildscript = String(take!(Downloads.download("https://raw.githubusercontent.com/JuliaPackaging/Yggdrasil/master/J/jlqml/build_tarballs.jl",IOBuffer())))
yggdrasil_up_to_date = contains(yggdrasil_buildscript, head_commit)

if yggdrasil_up_to_date
    touch(joinpath(mkdir("products"), "NOBUILD"))
    exit(0)
end

version = getversion(joinpath(name, "CMakeLists.txt"))

julia_versions = [v"1.9", v"1.11"]

# Collection of sources required to complete build
sources = [
    DirectorySource(name; target = name)
]

# Bash recipe for building across all platforms
script = raw"""
# Override compiler ID to silence the horrible "No features found" cmake error
if [[ $target == *"apple-darwin"* ]]; then
  macos_extra_flags="-DCMAKE_CXX_COMPILER_ID=AppleClang -DCMAKE_CXX_COMPILER_VERSION=10.0.0 -DCMAKE_CXX_STANDARD_COMPUTED_DEFAULT=11"
fi

mkdir build
cd build
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_FIND_ROOT_PATH=${prefix} \
    -DCMAKE_INSTALL_PREFIX=$prefix \
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN} \
    -DJulia_PREFIX=${prefix} \
    $macos_extra_flags \
    ../jlqml/
VERBOSE=ON cmake --build . --config Release --target install -- -j${nproc}
install_license $WORKSPACE/srcdir/jlqml*/LICENSE.md
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line

function libjulia_platforms(julia_version)
    platforms = supported_platforms(; experimental = julia_version ≥ v"1.7")

    filter!(p -> libc(p) != "musl" && arch(p) != "i686" && !contains(arch(p), "arm") && arch(p) != "aarch64" && arch(p) != "powerpc64le" && !Sys.isfreebsd(p), platforms)

    for p in platforms
        p["julia_version"] = string(julia_version)
    end

    platforms = expand_cxxstring_abis(platforms)

    filter!(p -> cxxstring_abi(p) != "cxx03", platforms)

    return platforms
end

platforms = vcat(libjulia_platforms.(julia_versions)...)

# The products that we will ensure are always built
products = [
    LibraryProduct("libjlqml", :libjlqml),
]

# Dependencies that must be installed before this package can be built
dependencies = [
    Dependency("libcxxwrap_julia_jll"),
    Dependency("Qt6Declarative_jll"; compat="~6.5.2"),
    HostBuildDependency("Qt6Declarative_jll"),
    Dependency("Qt6Svg_jll"; compat="~6.5.2"),
    BuildDependency("Libglvnd_jll"),
    BuildDependency("libjulia_jll"),
]

deployingargs = deepcopy(ARGS)
push!(deployingargs, "--deploy=local")

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(deployingargs, name, version, sources, script, platforms, products, dependencies;
    preferred_gcc_version = v"10", julia_compat = "1.6")
