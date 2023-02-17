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
using Shapefile, ArchGDAL, WellKnownGeometry
using GeoFormatTypes
using Polylabel
# utility packages
using DataDeps, DataFrames
using QRCode, Ghostscript_jll
using DataStructures, NaNMath
using DBInterface, MySQL
using Scratch, p7zip_jll
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


"""
    state_df[]::DataFrame

Contains the State dataframe
"""
const state_df = Ref{DataFrame}()

"""
    hr_df[]::DataFrame

Contains the HR dataframe
"""
const hr_df = Ref{DataFrame}()

"""
    district_df[]::DataFrame

Contains the District dataframe
"""
const district_df = Ref{DataFrame}()

const india_rivers = Ref{ArchGDAL.IGeometry}()

"""
    Karmana.__init__()

Initializes the package by loading geometries.  This is only really relevant to the `indiaoutline` recipe.

First, load the state, hr and district geometries of India from data.mayin.org, or the provided cache path.
Then, compute the intersection between the world's rivers (provided by env variable) and India, or load from cache stored in scratchspace.

"""
function __init__()

    has_india_data = false

    try
        _state_df, _hr_df, _district_df = state_hr_district_dfs()

        # _district_df[302, :hr_nmbr] = 3 # Kinnaur - district name not assigned HR_Name
        # _district_df[413, :hr_nmbr] = 3 # North Sikkim - district not assigned HR_Name nor district name
        state_df[] = _state_df
        hr_df[] = _hr_df
        district_df[] = _district_df
        has_india_data = true
    catch ex
        contingency_shapefile_path = get(ENV, "KARMANA_DISTRICT_SHAPEFILE", joinpath(dirname(dirname(dirname(@__DIR__))), "code", "maps", "DATA", "INDIA_SHAPEFILES", "Districts_States_HR", "2011_Districts_State_HR.shp"))
        if isfile(contingency_shapefile_path)
            district_df[] = DataFrame(Shapefile.Table(contingency_shapefile_path))
            district_df[].geometry = GeoMakie.geo2basic.(district_df[].geometry)
            # apply certain patches here
            district_df[][302, :HR_Nmbr] = 3 # Kinnaur - district name not assigned HR_Name
            district_df[][413, :HR_Nmbr] = 3 # North Sikkim - district not assigned HR_Name nor district name
            hr_df[] = _prepare_merged_geom_dataframe(district_df[], :HR_Nmbr, :ST_NM; capture_fields = (:ST_NM, :ST_CD, :HR_Name))
            state_df[] = _prepare_merged_geom_dataframe(district_df[], :ST_NM; capture_fields = (:ST_CD,))
            has_india_data = true
        else # no contingency shapefile detected
            printstyled("Error when trying to connect to the `maps` database at data.mayin.org!"; color = :red, bold = true)
            println()
            println("""
            Karmana.jl was not able to connect to the maps database on data.mayin.org.  
            
            This means that the `state_df`, `hr_df`, and `district_df` variables were not populated.

            Karmana.jl will still load, but if you want to use the `indiaoutline` recipe, you will have to populate those manually.
            If you have the correct district shapefile, pass its path to `Karmana.manually_set_state_hr_district!(shapefile_path)`.
            This will allow you to use `indiaoutline`.   In future, set the environment variable "KARMANA_DISRICT_SHAPEFILE" to this path.

            There is otherwise no disruption to Karmana.jl's functionality.

            The thrown exception is below:

            """)

            show(ex)

            return
        end
    finally
    end

    # get rivers
    if has_india_data
        # Since taking the intersection of all rivers with India is so expensive, we cache it as well-known-binary in a scratchspace.
        scratchspace = Scratch.@get_scratch!("india_rivers")
        cached_rivers_file = joinpath(scratchspace, "india_rivers.bin")
        # iIf we can't find the file, regenerate from scratch.  This takes time.
        if !isfile(cached_rivers_file)
            @info "India's rivers were not cached, so we are regenerating them.  This may take a minute or so.  Only on first run!"
            world_rivers_path = get(ENV, "KARMANA_RIVER_SHAPEFILE", joinpath(dirname(dirname(dirname(@__DIR__))), "code", "maps", "DATA", "INDIA_SHAPEFILES", "World_Rivers", "world_rivers.shp"))
            if !isfile(world_rivers_path)
                @warn "Rivers not found or environment variable not provided.  Downloading directly from UNESCO.]"
                # TODO: let this download from
                river_zipfile = Downloads.download("http://ihp-wins.unesco.org/geoserver/ows?service=WFS&version=1.0.0&request=GetFeature&typename=geonode%3Aworld_rivers&outputFormat=SHAPE-ZIP&srs=EPSG%3A4326&format_options=charset%3AUTF-8")
                temppath = mktempdir()
                run(pipeline(`$(p7zip_jll.p7zip()) e $river_zipfile -o$temppath -y `, stdout = devnull, stderr = devnull))
                world_rivers_path = joinpath(temppath, "world_rivers.shp")
            end
            # perform the operation
            india_rivers[] = prepare_merged_river_geom(
                world_rivers_path,
                merge_polys(state_df[].geometry)
            )

            # save this in well-known-binary form to the cache file.
            write(cached_rivers_file, GeoFormatTypes.val(WellKnownGeometry.getwkb(india_rivers[])))
        else # we have the cache, so can write to it.
            india_rivers[] = ArchGDAL.fromWKB(read(cached_rivers_file))
        end
    end

    return nothing
end


end
