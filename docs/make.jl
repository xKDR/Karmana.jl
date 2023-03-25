using Karmana
using Documenter, Literate

DocMeta.setdocmeta!(Karmana, :DocTestSetup, :(using Karmana); recursive=true)

makedocs(;
    modules=[Karmana],
    authors="Anshul Singhvi <anshulsinghvi@gmail.com> and contributors",
    repo="https://github.com/xKDR/Karmana.jl/blob/{commit}{path}#{line}",
    sitename="Karmana.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://xKDR.github.io/Karmana.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "API" => "api.md",
        # "Examples" => [
        #     "Basic Usage" => "examples/demo.md",
        #     "Ternary colormaps" => "examples/ternary_colormap.md",
        # ]
    ],
)

deploydocs(;
    repo="github.com/xKDR/Karmana.jl",
    devbranch="main",
    target = "build",
    push_previews = true,
)
