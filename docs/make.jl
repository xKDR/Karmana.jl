using Karmana
using Documenter, Literate

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

example_files = readdir(joinpath(dirname(@__DIR__), "examples"); join = true)

for example_file in example_files
    Literate.markdown(example_file, joinpath(@__DIR__, "src", "examples"); documenter = true) # TODO change this to true
end

# Special-case the capex example
# rm(joinpath(@__DIR__, "src", "examples", "annular_ring.md"), force = true)
# Literate.markdown(joinpath(dirname(@__DIR__), "examples", "capex.md"), joinpath(@__DIR__, "src", "examples"); documenter = true)

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
            "Capex geodesic utilities" => "examples/geodesic.md",
            "Annular rings on Rasters" => "examples/annular_ring.md"
        #     "Ternary colormaps" => "examples/ternary_colormap.md",
        ],
    ],
)

deploydocs(;
    repo="github.com/xKDR/Karmana.jl",
    devbranch="main",
    target = "build",
    push_preview = true,
)
