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
using LinearAlgebra, Dates, Downloads, DelimitedFiles

GeoInterfaceMakie.@enable(ArchGDAL.AbstractGeometry)
GeoInterfaceMakie.@enable(Shapefile.AbstractShape)

assetpath(args::AbstractString...) = abspath(dirname(@__DIR__), "assets", args...)

include("utils.jl")
include("geom_utils.jl")

include("themes.jl")
export theme_xkdr, theme_a1, theme_a2, theme_a3, theme_a4, paper_size_theme

include("poster_page.jl")
export create_page

include("ternary.jl")
export TernaryColormap

# the below code is mostly stuff internal to xKDR
include("data.jl")
export deltares_url

include("indiaoutline.jl")
export indiaoutline, indiaoutline!, IndiaOutline


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

    try
        if haskey(ENV, "KARMANA_DISTRICT_SHAPEFILE") && isfile(ENV["KARMANA_DISTRICT_SHAPEFILE"])
            error("Continue")
        end

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
            district_df[][413, :HR_Nmbr] = 3 # North Sikkim - district not assigned HR_Name nor district name # 104
            hr_df[] = _prepare_merged_geom_dataframe(district_df[], :HR_Nmbr, :ST_NM; capture_fields = (:ST_NM, :ST_CD, :HR_Name))
            state_df[] = _prepare_merged_geom_dataframe(district_df[], :ST_NM; capture_fields = (:ST_CD,))

            # finally, patch the loaded dataframes, to match the maps database

            rename!(state_df[], [:ST_NM => :st_nm, :ST_CD => :st_cen_cd])
            rename!(hr_df[], [:ST_NM => :st_nm, :ST_CD => :st_cen_cd, :HR_Name => :hr_name, :HR_Nmbr => :hr_nmbr]) # TODO: no hr_nmbr in data.mayin.org?
            hr_df[].hr_nmbr_str = ("HR ",) .* string.(hr_df[].hr_nmbr)
            rename!(district_df[], [:ST_NM => :st_nm, :ST_CD => :st_cen_cd, :HR_Name => :hr_name, :HR_Nmbr => :hr_nmbr, :DISTRCT => :district, :DT_CD => :dt_cen_cd, :CEN_CD => :censuscode])
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
        else # we have the cache, so can simply read from it.
            india_rivers[] = ArchGDAL.fromWKB(read(cached_rivers_file))
        end
    end

    return nothing
end


end


# klein(u, v) = Point3f((-2/15 * cos(u) * (
#     3*cos(v) - 30*sin(u) 
#   + 90 *cos(u)^4 * sin(u) 
#   - 60 *cos(u)^6 * sin(u)  
#   + 5 * cos(u)*cos(v) * sin(u))
#  ),
#  (-1/15 * sin(u) * (3*cos(v) 
#   - 3*cos(u)^2 * cos(v) 
#   - 48 * cos(u)^4*cos(v) 
#   + 48*cos(u)^6 *cos(v) 
#   - 60 *sin(u) 
#   + 5*cos(u)*cos(v)*sin(u) 
#   - 5*cos(u)^3 * cos(v) *sin(u) 
#   - 80*cos(u)^5 * cos(v)*sin(u) 
#   + 80*cos(u)^7 * cos(v) * sin(u))
#  ),
#  (2/15 * (3 + 5*cos(u) *sin(u))*sin(v)))

# us = LinRange(0, π, 41)
# vs = LinRange(0, 2π, 25)

# lines(klein.(us[5], vs))

# points = klein.(us', vs)

# xt, yt, zt = map(i -> getindex.(points, i), 1:3)

# index_color = (((u, v),) -> v + (u-1)*length(vs)).(tuple.(axes(us, 1)', axes(vs, 1)))
# u_color = first.(tuple.(us', vs))
# colormap = cgrad([:blue, :yellow, :orange, :red, :orange, :yellow, :blue])

# surface(xt, yt, zt; color = color, colormap = colormap, shading = false, axis = (; type = Axis3)) # causes strange error - I think the quad mesh we're using is actually wrong here!
# scatter(xt |> vec, yt |> vec, zt |> vec; color = u_color |> vec, colormap = :viridis) # produces the correct topology

# """
#     curvilinear_grid_mesh_discretesurface(xs, ys, zs, colors, colortrait = ContinuousSurface())

# Tesselates the grid defined by `xs` and `ys` in order to form a mesh with per-face coloring
# given by `colors`.

# The grid defined by `xs` and `ys` must have dimensions `(nx, ny) == size(colors) .+ 1`, as is the case for heatmap/image.
# """
# function curvilinear_grid_mesh(xs, ys, zs, colors = zs, colortrait::Makie.MakieCore.ConversionTrait = Makie.DiscreteSurface())
#     nx, ny = size(zs)
#     ni, nj = size(colors)
    
#     iteration_size = if colortrait isa Makie.DiscreteSurface
#         @assert (nx == ni+1) & (ny == nj+1) """
#             `curvilinear_grid_mesh` was provided a `DiscreteSurface()` plot trait, implying that the input coordinates define grid edges. 
#             Expected nx, ny = ni+1, nj+1; got nx=$nx, ny=$ny, ni=$ni, nj=$nj.  
#             nx/y are size(zs), ni/j are size(colors).
#             """
#         size(colors)
#     elseif colortrait isa Makie.ContinuousSurface
#         @assert (nx == ni) & (ny == nj) """
#         `curvilinear_grid_mesh` was provided a `ContinuousSurface()` plot trait, implying that the input coordinates define grid centers. 
#         Expected nx, ny = ni, nj; got nx=$nx, ny=$ny, ni=$ni, nj=$nj.  
#         nx/y are size(zs), ni/j are size(colors).
#         """
#         size(colors) .- 1
#     else
#         @error "`curvilinear_grid_mesh` only supports instances of `Makie.MakieCore.DiscreteSurface()` or `Makie.MakieCore.ContinuousSurface()`, of which the provided `colortrait` $colortrait is neither."
#     end

#     input_points_vec = Makie.matrix_grid(identity, xs, ys, zs)
#     input_points = reshape(input_points_vec, size(zs))

#     triangle_faces = Vector{GeometryBasics.TriangleFace{UInt32}}()
#     triangle_points = Vector{Point3f}()
#     triangle_colors = Vector{eltype(colors)}()
#     sizehint!(triangle_faces, size(input_points, 1) * size(input_points, 2) * 2)
#     sizehint!(triangle_points, size(input_points, 1) * size(input_points, 2) * 2 * 3)
#     sizehint!(triangle_colors, size(input_points, 1) * size(input_points, 2) * 3)

#     point_ind = 1
#     @inbounds for i in 1:iteration_size[1]
#         for j in 1:iteration_size[2]
#             # push two triangles to make a square
#             # to make this efficient, since we know the two triangles will have the same colour, 
#             # we can just assign the same colour to the points on the quad, which decreases the number of points per quad
#             # from 6 to 4.
#             push!(triangle_points, input_points[i, j])
#             push!(triangle_points, input_points[i+1, j])
#             push!(triangle_points, input_points[i+1, j+1])
#             push!(triangle_points, input_points[i, j+1])
#             # push vertex colors
#             push!(triangle_colors, colors[i, j]); push!(triangle_colors, colors[i, j]); push!(triangle_colors, colors[i, j]); push!(triangle_colors, colors[i, j])
#             # push triangle faces
#             push!(triangle_faces, GeometryBasics.TriangleFace{UInt32}((point_ind, point_ind+1, point_ind+2)))
#             push!(triangle_faces, GeometryBasics.TriangleFace{UInt32}((point_ind+2, point_ind+3, point_ind)))
#             point_ind += 4
#         end
#     end

#     return triangle_points, triangle_faces, triangle_colors
    
# end

# @recipe(KleinBottle) do scene
#     default_theme(scene)
# end

# function Makie.plot!(plot::KleinBottle)
#     us = LinRange(0, π, 41)
#     vs = LinRange(0, 2π, 25)

#     u_color = first.(tuple.(us', vs))


#     points = klein.(us', vs)

#     xt, yt, zt = map(i -> getindex.(points, i), 1:3)

#     meshp, meshf, meshc = curvilinear_grid_mesh(xt, yt, zt, u_color, ContinuousSurface())
#     msh = Makie.GeometryBasics.Mesh(meshp, meshf)
#     mesh!(plot, msh; color = meshc, colormap = :RdYlBu_8, shading = false)
#     wireframe!(plot, msh; color = :gray50)

#     return plot
# end
