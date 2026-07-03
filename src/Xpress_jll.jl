# Use baremodule to shave off a few KB from the serialized `.ji` file
baremodule Xpress_jll

using Base
using Base: UUID
import Downloads
import Pkg
import SHA
import JLLWrappers

# ---------------------------------------------------------------------------
# Resumable download helper.
#
# The Xpress wheel is several hundred MiB.  On Windows, WinHTTP / Schannel
# translates a mid-transfer TCP RST into ERROR_BROKEN_PIPE (232), so a single
# Downloads.download() call is unreliable on slow or flaky connections.
#
# _download_with_resume() persists the partial file in the Julia depot across
# Julia restarts and resumes via HTTP Range requests (PyPI's CDN supports
# them). On each call it tries up to MAX_RETRIES times. If the server does
# not honour the Range header it falls back to a fresh full download.
# ---------------------------------------------------------------------------
const _MAX_RETRIES = 5

_wheel_cache_dir() = joinpath(first(Base.DEPOT_PATH), "xpress_jll_cache")

# Download with retries; persists the partial file across Julia restarts in the
# depot cache so repeated failures don't restart from zero.
function _download_with_resume(url, dest)
    mkpath(dirname(dest))
    for attempt in 1:_MAX_RETRIES
        partial = isfile(dest) ? stat(dest).size : Int64(0)
        try
            if partial > 0
                @info "Xpress_jll: resuming download from $(round(partial / 1024^2, digits=1)) MiB…"
                remaining = dest * ".part"
                resp = Downloads.request(url;
                    output  = remaining,
                    headers = ["Range" => "bytes=$partial-"],
                    timeout = 600.0,
                )
                if resp.status == 206
                    open(dest, "a") do out
                        open(remaining, "r") do inp; write(out, inp) end
                    end
                    rm(remaining; force = true)
                else
                    mv(remaining, dest; force = true)
                end
            else
                Downloads.download(url, dest; timeout = 600.0)
            end
            return
        catch e
            isfile(dest * ".part") && rm(dest * ".part"; force = true)
            if attempt == _MAX_RETRIES
                rm(dest; force = true)
                error(
                    "Xpress_jll: download failed after $_MAX_RETRIES attempts.\n" *
                    "  URL: $url\n  Last error: $e",
                )
            end
            @warn "Xpress_jll: download attempt $attempt/$_MAX_RETRIES failed: $e. Retrying…"
        end
    end
end

# ---------------------------------------------------------------------------
# One-time artifact installer.
#
# Called at the start of every wrapper's __init__. Downloads the platform-
# specific Xpress wheel from PyPI, extracts it with 7-Zip, and registers the
# result as a Julia artifact in the local depot.  Subsequent calls return
# immediately because artifact_exists() short-circuits once the depot has it.
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

    wheel = joinpath(_wheel_cache_dir(), split(url, "/")[end])
    _download_with_resume(url, wheel)

    actual_sha256 = open(wheel, "r") do io
        bytes2hex(SHA.sha256(io))
    end
    actual_sha256 == sha256 ||
        error("Xpress: SHA-256 mismatch for $url\n  expected: $sha256\n  got: $actual_sha256")

    exe7z     = Pkg.PlatformEngines.exe7z()
    log_file  = tempname(; cleanup = false)
    actual_id = Pkg.Artifacts.create_artifact() do dir
        open(log_file, "w") do log_io
            run(pipeline(`$exe7z x -y $wheel -o$dir`; stdout = log_io, stderr = log_io))
        end
    end
    rm(log_file; force = true)
    rm(wheel; force = true)

    actual_id == expected || error(
        "Xpress: git-tree-sha1 mismatch after extracting wheel.\n" *
        "  expected: $(bytes2hex(expected.bytes))\n" *
        "  got:      $(bytes2hex(actual_id.bytes))\n" *
        "Run `julia --project=scripts scripts/update_artifacts.jl` to regenerate Artifacts.toml.",
    )
    @info "Xpress_jll: artifact installed successfully."
    return
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
