export libxprs

JLLWrappers.@generate_wrapper_header("Xpress")

JLLWrappers.@declare_library_product(libxprs, "libxprs.so.42")

function __init__()
    JLLWrappers.@generate_init_header()
    JLLWrappers.@init_library_product(
        libxprs,
        "lib/python3.11/site-packages/xpress/lib/libxprs.so.42",
        RTLD_LAZY | RTLD_DEEPBIND,
    )
    JLLWrappers.@generate_init_footer()
end  # __init__()
