module Karmana

# visualization packages
using Makie 
using Makie.FileIO, Makie.GeometryBasics, Makie.PlotUtils, Makie.Colors
using GeoInterfaceMakie, GeoMakie
using TernaryDiagrams, PerceptualColourMaps
# geographic information systems packages
using GeoInterface, Proj
# raster loading
using Rasters
# feature/vector geometry
using Shapefile, ArchGDAL
using Polylabel
# utility packages
using DataDeps
using QRCode, Ghostscript_jll
using DataStructures, NaNMath
using DBInterface, HTTP
# standard libraries
using LinearAlgebra, Dates, Downloads, DelimitedFiles

assetpath(args::AbstractString...) = abspath(dirname(@__DIR__), "assets", args...)

include("themes.jl")
include("geom_utils.jl")

include("ternary.jl")

end
