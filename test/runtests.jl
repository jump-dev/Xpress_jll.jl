# Copyright (c) 2024 Oscar Dowson, and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

using Test

using Xpress_jll

@testset "is_available" begin
    @test Xpress_jll.is_available()
end

@testset "libxprs" begin
    @test Xpress_jll.libxprs_path isa String
    buffer = Vector{Cchar}(undef, 8 * 24)
    GC.@preserve buffer begin
        p = pointer(buffer)
        r = @ccall libxprs.XPRSgetversion(p::Ptr{Cchar})::Cint
        @test r == 0
        @test unsafe_string(p) == "42.01.05"
    end
end
