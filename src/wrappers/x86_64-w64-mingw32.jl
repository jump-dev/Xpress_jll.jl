# Copyright (c) 2024 Oscar Dowson, and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

export libxprs

# FICO only publishes the Windows binaries as a .zip, which Pkg cannot install
# as an artifact. Until a .tar.gz is available, we download and extract the zip
# ourselves into the first depot, instead of using `Artifacts.toml`.

import Downloads
import SHA
import ZipArchives

const _ZIP_URL = "https://github.com/fico-xpress/releases/releases/download/v10.0.0/xp10.0.0_win_x86_64.zip"

const _ZIP_SHA256 = "7090ac31777b7fbbddac14e5c0f60c4eb43d8d67f933576b573df9b6825b923f"

function _unzip(zip_file::String, dest::String)
    r = ZipArchives.ZipReader(read(zip_file))
    for (i, name) in enumerate(ZipArchives.zip_names(r))
        path = normpath(joinpath(dest, name))
        if !startswith(path, dest)
            error("Unsafe path in $zip_file: $name")
        end
        if ZipArchives.zip_isdir(r, i)
            mkpath(path)
        else
            mkpath(dirname(path))
            write(path, ZipArchives.zip_readentry(r, i))
        end
    end
    return
end

function find_artifact_dir()
    dir = joinpath(Base.DEPOT_PATH[1], "xpress_jll", _ZIP_SHA256)
    if isfile(joinpath(dir, "bin", "xprs.dll"))
        return dir
    end
    mkpath(dirname(dir))
    zip_file = Downloads.download(_ZIP_URL)
    try
        sha256 = bytes2hex(open(SHA.sha256, zip_file))
        if sha256 != _ZIP_SHA256
            error("Checksum mismatch for $_ZIP_URL: got $sha256")
        end
        # Extract to a temporary directory first, so an interrupted extraction
        # is never mistaken for a complete one.
        tmp = mktempdir(dirname(dir))
        _unzip(zip_file, tmp)
        rm(dir; force = true, recursive = true)
        mv(tmp, dir)
    finally
        rm(zip_file; force = true)
    end
    return dir
end

eager_mode() = nothing

JLLWrappers.@declare_library_product(libxprs, "xprs.dll")

function __init__()
    JLLWrappers.@generate_init_header()
    JLLWrappers.@init_library_product(
        libxprs,
        "bin\\xprs.dll",
        RTLD_LAZY | RTLD_DEEPBIND,
    )
    JLLWrappers.@generate_init_footer()
end  # __init__()
