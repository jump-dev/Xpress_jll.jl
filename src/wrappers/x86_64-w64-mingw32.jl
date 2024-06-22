export libxprs

JLLWrappers.@generate_wrapper_header("Xpress")

JLLWrappers.@declare_library_product(libxprs, "xprs.dll")

function __init__()
    JLLWrappers.@generate_init_header()
    # There's a permission error with the conda binaries
    if (stat(artifact_dir).mode & 0o777) != 0o755
        chmod(artifact_dir, 0o755; recursive = true)
    end
    JLLWrappers.@init_library_product(
        libxprs,
        "Lib\\site-packages\\xpress\\lib\\xprs.dll",
        RTLD_LAZY | RTLD_DEEPBIND,
    )
    JLLWrappers.@generate_init_footer()
end  # __init__()
