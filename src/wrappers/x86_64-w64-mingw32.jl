export libxprs

JLLWrappers.@generate_wrapper_header("Xpress")

JLLWrappers.@declare_library_product(libxprs, "xprs.dll")

function __init__()
    _ensure_artifact_installed()
    JLLWrappers.@generate_init_header()
    # Pre-load all sibling DLLs so Windows can resolve xprs.dll's transitive
    # dependencies by name from the already-loaded module list, without needing
    # PATH manipulation.
    bin_dir = joinpath(artifact_dir, "xpresslibs", "bin")
    if isdir(bin_dir)
        for dll in filter(f -> endswith(f, ".dll") && f != "xprs.dll", readdir(bin_dir))
            try; dlopen(joinpath(bin_dir, dll), RTLD_LAZY | RTLD_GLOBAL); catch; end
        end
    end
    JLLWrappers.@init_library_product(
        libxprs,
        "xpresslibs/bin/xprs.dll",
        RTLD_LAZY | RTLD_DEEPBIND,
    )
    JLLWrappers.@generate_init_footer()
end  # __init__()
