# Copyright (c) 2024 Oscar Dowson, and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

using Tar, SHA, TOML

function get_artifact(data; version::String)
    filename = "xp$version" * "_$(data.asset).tar.gz"
    url = "https://github.com/fico-xpress/releases/releases/download/v$version/$filename"
    run(`wget -q -O $filename $url`)
    tree_hash = Tar.tree_hash(`gzip -dc $filename`; skip_empty = true)
    ret = Dict(
        "git-tree-sha1" => tree_hash,
        "arch" => data.arch,
        "os" => data.os,
        "download" => Any[
            Dict("sha256" => bytes2hex(open(sha256, filename)), "url" => url),
        ]
    )
    rm(filename)
    return ret
end

# The Windows release is only published as a .zip, which Pkg cannot download as
# an artifact, so it is not included here. Instead, it is downloaded when the
# package is loaded. See `src/wrappers/x86_64-w64-mingw32.jl`.
function main(; version)
    platforms = [
        (os = "linux", arch = "aarch64", asset = "linux_aarch64"),
        (os = "linux", arch = "x86_64", asset = "linux_x86_64"),
        (os = "macos", arch = "aarch64", asset = "macos_arm64"),
    ]
    output = Dict("Xpress" => get_artifact.(platforms; version))
    open(joinpath(dirname(@__DIR__), "Artifacts.toml"), "w") do io
        return TOML.print(io, output)
    end
    return
end

#   julia --project=scripts scripts/update_artifacts.jl`
#
# Update the Artifacts.toml file.
main(; version = "10.0.0")
