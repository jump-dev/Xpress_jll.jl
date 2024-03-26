# Copyright (c) 2024 Oscar Dowson, and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

using Tar, Inflate, SHA, TOML

function get_artifact(data; version::String)
    filename = "xpress-$version-$(data.pyversion).tar.bz2"
    url = "https://anaconda.org/fico-xpress/xpress/$version/download/$(data.conda)/$filename"
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

function main(; version = "8.13.4")
    platforms = [
        (os = "linux", arch = "x86_64", conda = "linux-64", pyversion = "py39_0"),
        (os = "macos", arch = "x86_64", conda = "osx-64", pyversion = "py39_0"),
        # (os = "macos", arch = "aarch64", conda = "osx-arm64", pyversion = "py311hb8ed652_0"),
        (os = "windows", arch = "x86_64", conda = "win-64", pyversion = "py39_0"),
    ]
    output = Dict("Xpress" => get_artifact.(platforms; version))
    open(joinpath(dirname(@__DIR__), "Artifacts.toml"), "w") do io
        return TOML.print(io, output)
    end
    return
end

#   julia --project=scripts scripts/update_artifacts.jl version`
#
# Update the Artifacts.toml file.
if !isempty(ARGS)
    main(; version = ARGS[1])
end
