using Karmana
using CairoMakie
using Documenter, Literate

CairoMakie.activate!(type = :png, px_per_unit = 2)

# on CI, set the raster data sources path to be cached!
# This enables us to download a bunch of raster data,
# and have it cached so it doesn't get re-downloaded.
if haskey(ENV, "CI")
    rasterdatasources_path = joinpath(DEPOT_PATH[1], "artifacts", "RasterDataSources")
    mkpath(rasterdatasources_path)
    ENV["RASTERDATASOURCES_PATH"] = rasterdatasources_path
end

DocMeta.setdocmeta!(Karmana, :DocTestSetup, :(using Karmana); recursive=true)

# Use the README as the homepage
cp(joinpath(dirname(@__DIR__), "README.md"), joinpath(@__DIR__, "src", "index.md"))

# Weave the Literate.jl files into Documenter markdown
example_files = readdir(joinpath(dirname(@__DIR__), "examples"); join = true)

for example_file in example_files
    Literate.markdown(example_file, joinpath(@__DIR__, "src", "examples"); documenter = true) # TODO change this to true
end

# Make the docs!
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
        "Plotting" => "plotting.md",
        "CPHS" => "cphs.md",
        "CapEx" => "capex.md",
        "Examples" => [
            "Basic Usage" => "examples/demo.md",
            "Creating a poster" => "examples/poster.md",
            "Capex geodesic utilities" => "examples/geodesic.md",
            "Annular rings on Rasters" => "examples/annular_ring.md",
            "Ternary colormaps" => "examples/ternary.md",
        ],
        "Developer documentation" => [
            "Autodocs" => "autodocs.md",
            "Artifacts" => "artifacts.md",
        ],
    ],
)

# TODOs here:
# - Make the documentation more beautiful by using `mkdocs` and Python
# - Add more descriptive info about the CPHS and Capex helper functions
# - If possible, add a pre-weaved example which was run on Crayshrimp
#   (so had access to all the nice data)

deploydocs(;
    repo="github.com/xKDR/Karmana.jl",
    devbranch="main",
    target = "build",
    push_preview = true,
)
