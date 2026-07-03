# Copyright (c) 2024 Oscar Dowson, and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

import Downloads
import p7zip_jll
using ArtifactUtils
using Pkg.Artifacts: bind_artifact!
using Pkg.BinaryPlatforms: Platform
using JSON, TOML

"""
    get_pypi_urls(version) -> Dict{String,NamedTuple}

Query the PyPI JSON API for `xpresslibs` at `version` and return a mapping
from platform tag (the last dash-segment of the wheel stem, e.g.
`"manylinux1_x86_64"`, `"win_amd64"`) to `(url, sha256)`.
"""
function get_pypi_urls(version::String)
    tmp = Downloads.download("https://pypi.org/pypi/xpresslibs/$version/json")
    data = JSON.parsefile(tmp)
    rm(tmp)
    result = Dict{String,NamedTuple{(:url, :sha256),Tuple{String,String}}}()
    for entry in data["urls"]
        filename = entry["filename"]::String
        endswith(filename, ".whl") || continue
        # Wheel filename: {name}-{ver}-{py}-{abi}-{platform}.whl
        tag = last(split(splitext(filename)[1], "-"))
        result[tag] = (
            url    = entry["url"]::String,
            sha256 = entry["digests"]["sha256"]::String,
        )
    end
    return result
end

"""
    find_wheel(os, arch, pypi_urls) -> Union{NamedTuple, Nothing}

Return the `(url, sha256)` entry in `pypi_urls` whose platform tag matches the
given `os` / `arch` pair, or `nothing` if no matching wheel exists.
"""
function find_wheel(os::String, arch::String, pypi_urls::Dict)
    for (tag, info) in pypi_urls
        matched = if os == "linux"
            occursin("linux", tag) && endswith(tag, arch == "aarch64" ? "aarch64" : "x86_64")
        elseif os == "macos"
            startswith(tag, "macosx") && endswith(tag, arch == "aarch64" ? "arm64" : "x86_64")
        elseif os == "windows"
            tag == "win_amd64"
        else
            false
        end
        matched && return info
    end
    return nothing
end

"""
    julia_platform(data) -> Platform

Convert an `(os, arch)` named tuple to a `Pkg.BinaryPlatforms.Platform`.
"""
function julia_platform(data)
    os = Dict("linux" => "linux", "macos" => "macos", "windows" => "windows")[data.os]
    return Platform(data.arch, os)
end

"""
    find_libxprs_name(dir, os) -> String

Scan the extracted wheel directory for the actual libxprs filename so that
wrapper files never need to hardcode a version number.
"""
function find_libxprs_name(dir::String, os::String)
    libdir = joinpath(dir, "xpresslibs", os == "windows" ? "bin" : "lib")
    pattern = os == "linux"   ? r"^libxprs\.so\." :
               os == "macos"  ? r"^libxprs\.dylib$" :
                                r"^xprs\.dll$"
    candidates = filter(f -> occursin(pattern, f), readdir(libdir))
    isempty(candidates) && error("Could not find libxprs in $libdir")
    return first(candidates)
end

"""
    wrapper_filename(data) -> String

Return the src/wrappers/*.jl filename for the given platform.
"""
function wrapper_filename(data)
    return Dict(
        ("linux",   "x86_64")  => "x86_64-linux-gnu.jl",
        ("linux",   "aarch64") => "aarch64-linux-gnu.jl",
        ("macos",   "x86_64")  => "x86_64-apple-darwin.jl",
        ("macos",   "aarch64") => "aarch64-apple-darwin.jl",
        ("windows", "x86_64")  => "x86_64-w64-mingw32.jl",
    )[(data.os, data.arch)]
end

"""
    write_wrapper(data, libname, wrappers_dir)

Write (or overwrite) the JLLWrappers source file for `data`'s platform using
the discovered `libname` so that no version number is hardcoded.
"""
function write_wrapper(data, libname::String, wrappers_dir::String)
    path = joinpath(wrappers_dir, wrapper_filename(data))
    libpath = data.os == "windows" ? "xpresslibs/bin/$libname" :
                                     "xpresslibs/lib/$libname"
    soname  = data.os == "macos"   ? "@rpath/$libname" : libname

    open(path, "w") do io
        println(io, "export libxprs")
        println(io)
        println(io, "JLLWrappers.@generate_wrapper_header(\"Xpress\")")
        println(io)
        println(io, "JLLWrappers.@declare_library_product(libxprs, \"$soname\")")
        println(io)
        println(io, "function __init__()")
        println(io, "    _ensure_artifact_installed()")
        println(io, "    JLLWrappers.@generate_init_header()")
        if data.os == "windows"
            println(io, "    # Pre-load all sibling DLLs so Windows can resolve xprs.dll's transitive")
            println(io, "    # dependencies by name from the already-loaded module list, without needing")
            println(io, "    # PATH manipulation.")
            println(io, "    bin_dir = joinpath(artifact_dir, \"xpresslibs\", \"bin\")")
            println(io, "    if isdir(bin_dir)")
            println(io, "        for dll in filter(f -> endswith(f, \".dll\") && f != \"xprs.dll\", readdir(bin_dir))")
            println(io, "            try; dlopen(joinpath(bin_dir, dll), RTLD_LAZY | RTLD_GLOBAL); catch; end")
            println(io, "        end")
            println(io, "    end")
        end
        println(io, "    JLLWrappers.@init_library_product(")
        println(io, "        libxprs,")
        println(io, "        \"$libpath\",")
        println(io, "        RTLD_LAZY | RTLD_DEEPBIND,")
        println(io, "    )")
        println(io, "    JLLWrappers.@generate_init_footer()")
        println(io, "end  # __init__()")
    end
    return
end

"""
    install_artifact(data, pypi_urls, artifacts_toml, wrappers_dir)

Download the wheel for `data.os`/`data.arch`, extract it, detect the actual
libxprs filename, update the wrapper source file, create a local artifact via
`ArtifactUtils.artifact_from_directory`, and bind it in `artifacts_toml` with
the wheel URL as a download source so end-users get the artifact automatically
via `Pkg.instantiate()` without needing to run this script.
"""
function install_artifact(data, pypi_urls::Dict, artifacts_toml::String, wrappers_dir::String)
    wheel_info = find_wheel(data.os, data.arch, pypi_urls)
    if wheel_info === nothing
        @warn "No PyPI wheel found for os=$(data.os) arch=$(data.arch); skipping"
        return
    end
    tmp = Downloads.download(wheel_info.url)
    artifact_id = mktempdir() do dir
        run(pipeline(`$(p7zip_jll.p7zip_path) x -y $tmp -o$dir`; stdout=devnull, stderr=devnull))
        libname = find_libxprs_name(dir, data.os)
        write_wrapper(data, libname, wrappers_dir)
        artifact_from_directory(dir)
    end
    rm(tmp)
    bind_artifact!(
        artifacts_toml,
        "Xpress",
        artifact_id;
        platform      = julia_platform(data),
        download_info = [(wheel_info.url, wheel_info.sha256)],
        force         = true,
        lazy          = false,
    )
    return
end

function main(; version)
    platforms = [
        (os = "linux",   arch = "aarch64"),
        (os = "linux",   arch = "x86_64"),
        (os = "macos",   arch = "x86_64"),
        (os = "macos",   arch = "aarch64"),
        (os = "windows", arch = "x86_64"),
    ]
    repo_root     = dirname(@__DIR__)
    artifacts_toml = joinpath(repo_root, "Artifacts.toml")
    wrappers_dir   = joinpath(repo_root, "src", "wrappers")
    pypi_urls = get_pypi_urls(version)
    isfile(artifacts_toml) && rm(artifacts_toml)
    for data in platforms
        install_artifact(data, pypi_urls, artifacts_toml, wrappers_dir)
    end
    # Rename [[Xpress.download]] → [[Xpress.wheel]] so that Pkg's standard
    # artifact installer does not attempt to fetch and unpack the .whl as a
    # .tar.gz (which would fail).  Our _ensure_artifact_installed() __init__
    # reads from the "wheel" key instead.
    content = read(artifacts_toml, String)
    write(artifacts_toml, replace(content, "[[Xpress.download]]" => "[[Xpress.wheel]]"))
    return
end

#   julia --project=scripts scripts/update_artifacts.jl
#
# Downloads each platform wheel from PyPI, extracts it, detects the actual
# libxprs filename, regenerates the src/wrappers/*.jl files, installs the
# artifact into the local Julia depot, and writes Artifacts.toml entries
# referenced by git-tree-sha1 only (no remote download URL).
main(; version = "9.9.0")
