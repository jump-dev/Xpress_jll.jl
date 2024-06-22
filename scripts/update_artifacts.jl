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

function main(; version = "9.4.1")
    platforms = [
        (os = "linux", arch = "aarch64", conda = "linux-aarch64", pyversion = "py311ha86f405_1716201308"),
        (os = "linux", arch = "x86_64", conda = "linux-64", pyversion = "py311hcb34f93_1716205343"),
        (os = "macos", arch = "x86_64", conda = "osx-64", pyversion = "py311h2222352_1716216153"),
        (os = "macos", arch = "aarch64", conda = "osx-arm64", pyversion = "py311h5c123a4_1716198148"),
        (os = "windows", arch = "x86_64", conda = "win-64", pyversion = "py311hccbcb6a_1716202152"),
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
