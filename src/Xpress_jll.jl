# Use baremodule to shave off a few KB from the serialized `.ji` file
baremodule Xpress_jll

using Base
using Base: UUID
import Downloads
import Pkg
import SHA
import JLLWrappers

# ---------------------------------------------------------------------------
# One-time artifact installer.
#
# On first import, _once() downloads the platform-specific Xpress wheel from
# PyPI, extracts it with 7-Zip, and registers the result as a Julia artifact
# in the local depot.  Subsequent imports return immediately because
# Base.OncePerProcess guarantees the block runs at most once per Julia process,
# and the fast artifact_exists() check short-circuits after the first run.
# ---------------------------------------------------------------------------
function _ensure_artifact_installed()
    artifacts_toml = joinpath(@__DIR__, "..", "Artifacts.toml")
    platform = Pkg.BinaryPlatforms.HostPlatform()
    meta = Pkg.Artifacts.artifact_meta("Xpress", artifacts_toml; platform = platform)
    meta === nothing && return

    expected = Base.SHA1(meta["git-tree-sha1"])
    Pkg.Artifacts.artifact_exists(expected) && return  # already in depot

    dl = Base.get(meta, "download", [])
    isempty(dl) && error(
        "Xpress: no download sources found in Artifacts.toml. " *
        "Run `julia --project=scripts scripts/update_artifacts.jl` to regenerate.",
    )
    url    = dl[1]["url"]
    sha256 = dl[1]["sha256"]

    @info "Xpress_jll: downloading wheel from PyPI…"
    wheel = Downloads.download(url)

    actual_sha256 = open(wheel, "r") do io
        bytes2hex(SHA.sha256(io))
    end
    actual_sha256 == sha256 ||
        error("Xpress: SHA-256 mismatch for $url\n  expected: $sha256\n  got: $actual_sha256")

    exe7z    = Pkg.PlatformEngines.exe7z()
    actual_id = Pkg.Artifacts.create_artifact() do dir
        run(`$exe7z x -y $wheel -o$dir`)
    end
    rm(wheel)

    actual_id == expected || error(
        "Xpress: git-tree-sha1 mismatch after extracting wheel.\n" *
        "  expected: $(bytes2hex(expected.bytes))\n" *
        "  got:      $(bytes2hex(actual_id.bytes))\n" *
        "Run `julia --project=scripts scripts/update_artifacts.jl` to regenerate Artifacts.toml.",
    )
    @info "Xpress_jll: artifact installed successfully."
    return
end

const _once = Base.OncePerProcess{Nothing}() do
    _ensure_artifact_installed()
    nothing
end

JLLWrappers.@generate_main_file_header("Xpress")
JLLWrappers.@generate_main_file("Xpress", UUID("308bddfa-7f95-4fa6-a557-f2c7addc1869"))

"""
    print_shrinkwrap_license(io = stdout)

Print the Shrinkwrap License Agreement that governs the usage of the Xpress
artifacts.
"""
function print_shrinkwrap_license(io = stdout)
    license = joinpath(artifact_dir, "xpresslibs-9.9.0.dist-info", "licenses", "LICENSE.txt")
    print(io, read(license, String))
    return
end

export print_shrinkwrap_license

end  # module Xpress_jll
