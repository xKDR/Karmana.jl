
Base.convert(::Type{GeometryBasics.MultiPolygon}, poly::GeometryBasics.Polygon) = GeometryBasics.MultiPolygon([poly])
Base.convert(::Type{GeometryBasics.MultiPolygon}, multipoly::GeometryBasics.MultiPolygon) = multipoly

"""
    merge_polys(polys::AbstractVector{<: Union{Polygon, MultiPolygon}})

Merges a vector of polygons into a single `MultiPolygon` using `ArchGDAL.union`.

Returns an ArchGDAL geometry.
"""
function merge_polys(polys::AbstractVector)

    arch_polys = GeoInterface.convert.((ArchGDAL,), polys)

    # first, operate on the simplest cases
    if length(polys) == 1
        return convert(GeometryBasics.MultiPolygon, GeoInterface.convert(GeometryBasics, polys[1]))
    elseif length(polys) == 2
        return convert(GeometryBasics.MultiPolygon, GeoInterface.convert(GeometryBasics, ArchGDAL.union(arch_polys...)))
    end

    # create one master polygon for the others to merge into
    master_poly = ArchGDAL.union(arch_polys[1], arch_polys[2])
    # loop through the rest of the polygons and merge them in
    for poly in arch_polys[3:end]
        master_poly = ArchGDAL.union(master_poly, poly)
    end

    converted = GeoInterface.convert(GeometryBasics, GeoInterface.convert(GeometryBasics, master_poly))
    if converted isa GeometryBasics.Polygon
        return GeometryBasics.MultiPolygon([converted])
    elseif converted isa GeometryBasics.MultiPolygon
        return converted
    else
        @error "Unexpected type $(show(typeof(converted); compact = true)) received from conversion to GeometryBasics type - expected Polygon or MultiPolygon."
    end
end


"""
    prepare_merged_geom_dataframe(df::DataFrame, hr_column_id::Symbol; capture_cols::Tuple{Symbol})

Prepares a dataframe of merged geometries by grouping `df` by `hr_column_id`.  
The values of each of the `capture_cols` in the first row of each group are also 
included in the new dataframe, along with the value of  `hr_column_id`.  
Each group in the input corresponds to a row in the output dataframe.

This method assumes that there is a `geometry` column in the DataFrame which contains
objects which have a `MultiPolygonTrait` in GeoInterface.

Returns a DataFrame.
"""
function _prepare_merged_geom_dataframe(district_df::DataFrame, merge_column_id::Symbol...; capture_fields = (:ST_NM, :ST_CD, :HR_Name))
    merge_grouped = groupby(district_df, collect(merge_column_id))

    colpairs = [
        :geometry => GeometryBasics.MultiPolygon{2}[], 
        first(merge_column_id) => eltype(getproperty(district_df, first(merge_column_id)))[],
        (field => eltype(getproperty(district_df, field))[] for field in capture_fields)...
    ]

    sizehint!.(last.(colpairs), length(merge_grouped))

    new_df = DataFrame(
        colpairs...
        )
    
    for (merge_column_key, merge_df) in pairs(merge_grouped)
        push!(new_df, (
            merge_polys(merge_df.geometry),
            getproperty(merge_column_key, first(merge_column_id)),
            (merge_df[1, field] for field in capture_fields)...
        ))
    end

    return new_df
end

"""
    prepare_merged_river_geom(shapefile_path, mask_poly)

Uses ArchGDAL to prepare a multilinestring which shows river paths within India.
"""
function prepare_merged_river_geom(shapefile_path, mask_poly)
    river_table = Shapefile.Table(shapefile_path)
    archgdal_mask_poly = GeoInterface.convert(ArchGDAL, mask_poly);
    archgdal_rivers = GeoInterface.convert.((ArchGDAL,), river_table.geometry);
    # compute the point-set intersection between India and the set of all rivers.
    india_river_geoms = map(x -> ArchGDAL.intersection(archgdal_mask_poly, x), archgdal_rivers) 
    # merge all of these intersections into one MultiLineString
    return reduce(ArchGDAL.union, india_river_geoms)
end

function load_karmana_geom_resources()
    # warning: use name for everything but HR when joining!
    # .(src)/..(Karmana.jl)/..(dev)/code/maps/DATA/...
    india_shapefiles_folder = (abspath(joinpath(dirname(dirname(dirname(@__DIR__))), "code", "maps", "DATA", "INDIA_SHAPEFILES")))
    district_df = Shapefile.Table(joinpath(india_shapefiles_folder, "Districts_States_HR", "2011_Districts_State_HR.shp")) |> DataFrame
    district_df.geometry = GeoInterface.convert.((GeometryBasics,), district_df.geometry)
    # apply patches to known issues in districts
    district_df[302, :HR_Nmbr] = 3 # Kinnaur - district name not assigned HR_Name
    district_df[413, :HR_Nmbr] = 3 # North Sikkim - district not assigned HR_Name nor district name
    
    hr_df = (_prepare_merged_geom_dataframe(district_df, :HR_Nmbr, :ST_NM; capture_fields = (:ST_NM, :ST_CD, :HR_Name)))
    state_df = (_prepare_merged_geom_dataframe(district_df, :ST_NM; capture_fields = (:ST_CD,)))
    # now, we extract the relevant rivers
    india_merged_river_geom = (prepare_merged_river_geom(
        joinpath(india_shapefiles_folder, "World_Rivers", "world_rivers.shp"),
        merge_polys(state_df.geometry)
    ))

    return state_df, hr_df, district_df, india_merged_river_geom
end

 
# Projection stuff
# remove once Proj's PR for this hits
function do_transform(trans::Proj.Transformation, poly::GeometryBasics.MultiPolygon)
    return GeometryBasics.MultiPolygon(do_transform.((trans,),poly.polygons))
end

function do_transform(trans::Proj.Transformation, poly::GeometryBasics.Polygon{N, T}) where {N, T}
    if isempty(poly.interiors)
        return GeometryBasics.Polygon(do_transform(trans, poly.exterior))
    else
        return GeometryBasics.Polygon(do_transform(trans, poly.exterior), do_transform.((trans,), poly.interiors))
    end
end

do_transform(trans::Proj.Transformation, ls::GeometryBasics.LineString) = GeometryBasics.LineString(do_transform.((trans,), ls))

do_transform(trans::Proj.Transformation, l::Line) = GeometryBasics.Line(do_transform(trans, l[1]), do_transform(trans, l[2]))

function do_transform(trans::Proj.Transformation, point::GeometryBasics.Point{N, T}) where {N, T}
    return GeometryBasics.Point{N, T}(trans(point...))
end
