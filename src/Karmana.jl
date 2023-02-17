"""
    Karmana.jl

This module is built t
"""
module Karmana

# visualization packages
using Makie 
using Makie.FileIO, Makie.GeometryBasics, Makie.PlotUtils, Makie.Colors
using GeoInterfaceMakie, GeoMakie
using TernaryDiagrams
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

include("utils.jl")
include("geom_utils.jl")

include("data.jl")
export deltares_url

include("themes.jl")
export theme_xkdr, theme_a1, theme_a2, theme_a3, theme_a4, paper_size_theme

include("poster_page.jl")
export create_page


include("ternary.jl")
export TernaryColormap


end
