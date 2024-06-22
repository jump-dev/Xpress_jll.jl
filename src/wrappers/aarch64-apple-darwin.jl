export libxprs

JLLWrappers.@generate_wrapper_header("Xpress")

JLLWrappers.@declare_library_product(libxprs, "@rpath/libxprs.dylib")

function __init__()
    JLLWrappers.@generate_init_header()
    JLLWrappers.@init_library_product(
        libxprs,
        "/lib/libxprs.dylib",
        RTLD_LAZY | RTLD_DEEPBIND,
    )
    JLLWrappers.@generate_init_footer()
end  # __init__()
