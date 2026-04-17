# Copyright (c) 2024 Oscar Dowson, and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

using Tar, Inflate, SHA, TOML

function get_artifact(data; version::String)
    filename = "xpresslibs-$version-$(data.pyversion).tar.bz2"
    url = "https://anaconda.org/fico-xpress/xpresslibs/$version/download/$(data.conda)/$filename"
    run(`wget $url`)
    ret = Dict(
        "git-tree-sha1" => Tar.tree_hash(`gzcat $filename`),
        "arch" => data.arch,
        "os" => data.os,
        "download" => Any[
            Dict("sha256" => bytes2hex(open(sha256, filename)), "url" => url),
        ]
    )
    rm(filename)
    return ret
end

function main(; version)
    platforms = [
        (os = "linux", arch = "aarch64", conda = "linux-aarch64", pyversion = "1771425923"),
        (os = "linux", arch = "x86_64", conda = "linux-64", pyversion = "1771425194"),
        (os = "macos", arch = "x86_64", conda = "osx-64", pyversion = "1771424591"),
        (os = "macos", arch = "aarch64", conda = "osx-arm64", pyversion = "1771423794"),
        (os = "windows", arch = "x86_64", conda = "win-64", pyversion = "1771428111"),
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
main(; version = "9.8.1")
