export libxprs

JLLWrappers.@generate_wrapper_header("Xpress")

JLLWrappers.@declare_library_product(libxprs, "xprs.dll")

function __init__()
    JLLWrappers.@generate_init_header()
    JLLWrappers.@init_library_product(
        libxprs,
        "Lib\\site-packages\\xpress\\lib\\xprs.dll",
        RTLD_LAZY | RTLD_DEEPBIND,
    )
    JLLWrappers.@generate_init_footer()
    # There's a permission error with the conda binaries
    chmod(dirname(dirname(libxprs)), 0o755; recursive = true)
end  # __init__()
