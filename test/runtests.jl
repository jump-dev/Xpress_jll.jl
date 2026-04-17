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
        @test unsafe_string(p) == "46.01.02"
    end
end

@testset "print_shrinkwrap_license" begin
    contents = sprint(print_shrinkwrap_license)
    @test occursin("Shrinkwrap", contents)
    @test length(contents) > 1_000
end

using Xpress_jll: libxprs

function test_segfault()
    XPRS_NLPSOLVER = 12417
    XPRS_NLPSOLVER_LOCAL = 1
    XPRS_IFUN_SQRT = 18
    XPRS_IFUN_PROD = 37
    XPRS_TOK_EOF = 0
    XPRS_TOK_CON = 1
    XPRS_TOK_COL = 10
    XPRS_TOK_IFUN = 12
    XPRS_TOK_RB = 22
    path_lic = joinpath(dirname(@__DIR__), "xpauth.xpr")
    license = Cint[1]
    @ccall libxprs.XPRSlicense(license::Ptr{Cint}, path_lic::Cstring)::Cint
    @ccall libxprs.XPRSlicense(license::Ptr{Cint}, path_lic::Cstring)::Cint
    @ccall libxprs.XPRSinit(C_NULL::Cstring)::Cint
    ref = Ref{Ptr{Cvoid}}()
    @ccall libxprs.XPRScreateprob(ref::Ptr{Ptr{Cvoid}})::Cint
    prob = ref[]
    @ccall libxprs.XPRSaddcols(
        prob::Ptr{Cvoid},
        2::Cint,
        0::Cint,
        [0.0, 0.0]::Ptr{Cdouble},
        C_NULL::Ptr{Cint},
        C_NULL::Ptr{Cint},
        C_NULL::Ptr{Cdouble},
        [2.0, 3.0]::Ptr{Cdouble},
        [2.0, 3.0]::Ptr{Cdouble},
    )::Cint
    @ccall libxprs.XPRSaddrows(
        prob::Ptr{Cvoid},
        1::Cint,
        0::Cint,
        Cchar['L']::Ptr{UInt8},
        [4.0]::Ptr{Cdouble},
        C_NULL::Ptr{Cdouble},
        C_NULL::Ptr{Cint},
        C_NULL::Ptr{Cint},
        C_NULL::Ptr{Cdouble},
    )::Cint
    type = Cint[XPRS_TOK_RB, XPRS_TOK_RB, XPRS_TOK_COL, XPRS_TOK_COL, XPRS_TOK_CON, XPRS_TOK_IFUN, XPRS_TOK_IFUN, XPRS_TOK_EOF]
    value = Cdouble[0.0, 0.0, 1.0, 0.0, 2.0, XPRS_IFUN_PROD, XPRS_IFUN_SQRT, 0.0]
    @ccall libxprs.XPRSnlpchgformula(
        prob::Ptr{Cvoid},
        0::Cint,
        1::Cint,
        type::Ptr{Cint},
        value::Ptr{Cdouble},
    )::Cint
    @ccall libxprs.XPRSsetintcontrol(
        prob::Ptr{Cvoid},
        XPRS_NLPSOLVER::Cint,
        XPRS_NLPSOLVER_LOCAL::Cint,
    )::Cint
    solvestatusP, solstatusP = Ref{Cint}(0), Ref{Cint}(0)
    @ccall libxprs.XPRSoptimize(
        prob::Ptr{Cvoid},
        ""::Cstring,
        solvestatusP::Ptr{Cint},
        solstatusP::Ptr{Cint},
    )::Cint
    @ccall libxprs.XPRSdestroyprob(prob::Ptr{Cvoid})::Cint
    return
end

test_segfault()
