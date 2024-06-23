# Use baremodule to shave off a few KB from the serialized `.ji` file
baremodule Xpress_jll

using Base
using Base: UUID
import JLLWrappers

JLLWrappers.@generate_main_file_header("Xpress")
JLLWrappers.@generate_main_file("Xpress", UUID("308bddfa-7f95-4fa6-a557-f2c7addc1869"))

"""
    print_shrinkwrap_license(io = stdout)

Print the Shrinkwrap License Agreement that governs the usage of the Xpress
artifacts.
"""
function print_shrinkwrap_license(io = stdout)
    license = if Sys.islinux()
        joinpath(artifact_dir, "info", "licenses", "LICENSE.txt")
    else
        joinpath(artifact_dir, "info", "LICENSE.txt")
    end
    print(io, read(license, String))
    return
end

export print_shrinkwrap_license

end  # module Xpress_jll
