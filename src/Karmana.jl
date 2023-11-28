module Karmana

# Load Karmana.jl's README.md as the docstring for the module!
Base.@doc read(joinpath(dirname(@__DIR__), "README.md"), String) Karmana

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
using LinearAlgebra, Dates, Downloads, DelimitedFiles, Pkg
using Pkg.Artifacts

GeoInterfaceMakie.@enable(ArchGDAL.AbstractGeometry)
GeoInterfaceMakie.@enable(Shapefile.AbstractShape)

assetpath(args::AbstractString...) = abspath(dirname(@__DIR__), "assets", args...)



include("utils.jl")
include("geom_utils.jl")

# the below code is mostly stuff internal to xKDR
include("data.jl")
include("readnl.jl")
export readnl
export deltares_url

############################################################
#                Plotting and visualization                #
############################################################

include("plotting/themes.jl")
export theme_xkdr, theme_a1, theme_a2, theme_a3, theme_a4, paper_size_theme

include("plotting/poster_page.jl")
export create_page

include("plotting/ternary.jl")
include("plotting/ternary_colorlegend.jl")
export TernaryColormap, TernaryColorlegend

include("plotting/indiaoutline.jl")
export indiaoutline, indiaoutline!, IndiaOutline

############################################################
#                   CMIE CapEx database                    #
############################################################

include("capex.jl")
export latlong_string_to_points, points_weights
export line_to_geodetic_width_poly, annular_ring

############################################################
#                    CMIE CPHS database                    #
############################################################

include("cphs.jl")
export get_HR_number, get_sentiment_props

############################################################


"""
Contains the State dataframe
"""
const state_df = Ref{DataFrame}()

"""
Contains the HR dataframe
"""
const hr_df = Ref{DataFrame}()

"""
Contains the District dataframe
"""
const district_df = Ref{DataFrame}()

"""
Contains an `ArchGDAL.IGeometry` which contains a multilinestring of
the intersection of the world's rivers with India.
"""
const india_rivers = Ref{ArchGDAL.IGeometry}()

"""
    Karmana.__init__()

Initializes the package by loading geometries.  This is only really relevant to the `indiaoutline` recipe.

First, load the state, hr and district geometries of India from data.mayin.org, or the provided cache path.
Then, compute the intersection between the world's rivers (provided by env variable) and India, or load from cache stored in scratchspace.

"""
function __init__()

    has_india_data = false

    has_maps_db_config = haskey(ENV, "MAPS_USER") && haskey(ENV, "MAPS_PASSWORD")
    has_karmana_shapefile_config = haskey(ENV, "KARMANA_DISTRICT_SHAPEFILE")

    if has_karmana_shapefile_config && !isfile(ENV["KARMANA_DISTRICT_SHAPEFILE"])
        @warn """
        `KARMANA_DISTRICT_SHAPEFILE` was set to `$(ENV["KARMANA_DISTRICT_SHAPEFILE"])
        but that isn't a valid path.  Ignoring this setting.
        """
        has_karmana_shapefile_config = false
    end


    if has_karmana_shapefile_config # env var takes precedence over all else
        # load the district dataframe
        district_df[] = DataFrame(Shapefile.Table(ENV["KARMANA_DISTRICT_SHAPEFILE"]))
        # convert the geometry to GeometryBasics so it can be directly plotted and manipulated
        district_df[].geometry = GeoInterface.convert.((GeometryBasics,), district_df[].geometry)
        # apply certain patches here, if needed
        if get(ENV, "KARMANA_APPLY_SHAPEFILE_PATCHES", "true") == "true"
            district_df[][302, :HR_Nmbr] = 3 # Kinnaur - district name not assigned HR_Name
            district_df[][413, :HR_Nmbr] = 3 # North Sikkim - district not assigned HR_Name nor district name # 104
        end
        hr_df[] = _prepare_merged_geom_dataframe(district_df[], :HR_Nmbr, :ST_NM; capture_fields = (:ST_NM, :ST_CD, :HR_Name))
        state_df[] = _prepare_merged_geom_dataframe(district_df[], :ST_NM; capture_fields = (:ST_CD,))

        # finally, patch the loaded dataframes, to match the maps database
        if get(ENV, "KARMANA_APPLY_SHAPEFILE_PATCHES", "true") == "true"
            rename!(state_df[], [:ST_NM => :st_nm, :ST_CD => :st_cen_cd])
            rename!(hr_df[], [:ST_NM => :st_nm, :ST_CD => :st_cen_cd, :HR_Name => :hr_name, :HR_Nmbr => :hr_nmbr]) # TODO: no hr_nmbr in data.mayin.org?
            hr_df[].hr_nmbr_str = ("HR ",) .* string.(hr_df[].hr_nmbr)
            rename!(district_df[], [:ST_NM => :st_nm, :ST_CD => :st_cen_cd, :HR_Name => :hr_name, :HR_Nmbr => :hr_nmbr, :DISTRCT => :district, :DT_CD => :dt_cen_cd, :CEN_CD => :censuscode])
        end
        # finally, we're done!
        has_india_data = true

    elseif has_maps_db_config
        try
            _state_df, _hr_df, _district_df = state_hr_district_dfs()

            # _district_df[302, :hr_nmbr] = 3 # Kinnaur - district name not assigned HR_Name
            # _district_df[413, :hr_nmbr] = 3 # North Sikkim - district not assigned HR_Name nor district name
            state_df[] = _state_df
            hr_df[] = _hr_df
            district_df[] = _district_df
            has_india_data = true
        catch e
            @warn "Failed to load data from maps database.  Falling back to shapefile."
            @warn e
            has_india_data = false
        end
    end

    if !has_india_data # no shapefile path, no maps db access ⟹ use the artifact!
        # WARNING: you have to change this path each version 
        district_df[] = DataFrame(Shapefile.Table(joinpath(artifact"india_shapefile", "india-maps-0.2.0", "Districts", "2011_Districts_State_HR.shp")))
        # convert the geometry to GeometryBasics so it can be directly plotted and manipulated
        district_df[].geometry = GeoInterface.convert.((GeometryBasics,), district_df[].geometry)
        # apply certain patches here, if needed
        district_df[][302, :HR_Nmbr] = 3 # Kinnaur - district name not assigned HR_Name
        district_df[][413, :HR_Nmbr] = 3 # North Sikkim - district not assigned HR_Name nor district name # 104
        hr_df[] = _prepare_merged_geom_dataframe(district_df[], :HR_Nmbr, :ST_NM; capture_fields = (:ST_NM, :ST_CD, :HR_Name))
        state_df[] = _prepare_merged_geom_dataframe(district_df[], :ST_NM; capture_fields = (:ST_CD,))

        # finally, patch the loaded dataframes, to match the maps database
        rename!(state_df[], [:ST_NM => :st_nm, :ST_CD => :st_cen_cd])
        rename!(hr_df[], [:ST_NM => :st_nm, :ST_CD => :st_cen_cd, :HR_Name => :hr_name, :HR_Nmbr => :hr_nmbr]) # TODO: no hr_nmbr in data.mayin.org?
        hr_df[].hr_nmbr_str = ("HR ",) .* string.(hr_df[].hr_nmbr)
        rename!(district_df[], [:ST_NM => :st_nm, :ST_CD => :st_cen_cd, :HR_Name => :hr_name, :HR_Nmbr => :hr_nmbr, :DISTRCT => :district, :DT_CD => :dt_cen_cd, :CEN_CD => :censuscode])

    end

    # TODO: implement some kind of caching, 
    # so we don't have to merge all these polygons all the time.

    # get rivers
    # Since taking the intersection of all rivers with India is so expensive, we cache it as well-known-binary in a scratchspace.
    scratchspace = Scratch.@get_scratch!("india_rivers")
    cached_rivers_file = joinpath(scratchspace, "india_rivers.bin")
    # iIf we can't find the file, regenerate from scratch.  This takes time.
    if !isfile(cached_rivers_file)
        @info "India's rivers were not cached, so we are regenerating them.  This may take a minute or so.  Only on first run!"
        world_rivers_path = joinpath(artifact"india_shapefile", "india-maps-0.2.0", "World_Rivers", "world_rivers.shp")
        # perform the operation
        india_rivers[] = prepare_merged_river_geom(
            world_rivers_path,
            merge_polys(state_df[].geometry)
        )

        # save this in well-known-binary form to the cache file.
        write(cached_rivers_file, GeoFormatTypes.val(WellKnownGeometry.getwkb(india_rivers[])))
    else # we have the cache, so can simply read from it.
        india_rivers[] = ArchGDAL.fromWKB(read(cached_rivers_file))
    end

    return nothing
end


end # module
