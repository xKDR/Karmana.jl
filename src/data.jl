# Deltares World Flood dataset
function deltares_url(year::Int; dem_source = "NASADEM", return_period = "0100")
    root = (
        "https://deltaresfloodssa.blob.core.windows.net/floods/v2021.06"
    )

    path = "$(root)/global/$(dem_source)/90m"
    file_name = "GFM_global_$(dem_source)90m_$(year)slr_rp$(return_period)_masked.nc"

    return "$(path)/$(file_name)"
end

function validate_deltares_params(year::Int, dem_source::Int, return_period::Int)
    ret_pd = lpad(string(return_period), 4, '0')

    url = deltares_url(year; dem_source, return_period = ret_pd)

    try
        Downloads.download(url)
    catch
    end
end


# CPHS map geometry + ID data


function maps_db_connection()

    maps_user = get(ENV, "MAPS_USER", "invalid")
    maps_password = get(ENV, "MAPS_PASSWORD", "invalid")

    maps_user == "invalid" && @error("The environment variable `MAPS_USER` was not found.  It must be provided in order to access the database.")
    maps_password == "invalid" && @error("The environment variable `MAPS_PASSWORD` was not found.  It must be provided in order to access the database.")

    return DBInterface.connect(MySQL.Connection, "data.mayin.org", maps_user, maps_password, db = "maps")
end

function do_geoquery(connection, layer; geometrycols = ["SHAPE"]) 
    result = DataFrame(DBInterface.execute(connection, "SELECT *, $(join("ST_AsBinary(" .* geometrycols .* ") as " .* geometrycols .* "_wkb", ", ", "")) FROM $layer"))
    DataFrames.select!(result, Not(geometrycols...))
    return result
end

function shape_wkb_to_module_geom!(mod::Module, table::DataFrame; new_colname = :geometry, wkb_colname = :SHAPE_wkb)
    archgdal_geoms = ArchGDAL.fromWKB.(table[!, wkb_colname])
    table[!, new_colname] = GeoInterface.convert.((mod,), archgdal_geoms)
    DataFrames.select!(table, Not(wkb_colname))
    return table
end

function state_hr_district_dfs()
    # connect to the database
    connection = maps_db_connection()
    # get the CRS (if on another DB)
    spatial_ref_df = DBInterface.execute(connection, "SELECT * from spatial_ref_sys") |> DataFrame
    db_crs = spatial_ref_df.SRTEXT[begin] # TODO: use this when converting.
    # get tables for each admin level
    state_table = do_geoquery(connection, "states")
    hr_table = do_geoquery(connection, "homogeneous_regions")
    district_table = do_geoquery(connection, "districts_2011")
    # get rivers etc
    shape_wkb_to_module_geom!(GeometryBasics, state_table)
    shape_wkb_to_module_geom!(GeometryBasics, hr_table)
    shape_wkb_to_module_geom!(GeometryBasics, district_table)

    DBInterface.close!(connection)

    return state_table, hr_table, district_table

end

# old code
# read_the_map = st_read(dsn=dsn_for_maps, layer  = aggregation.layer)
# map_with_crs = read_the_map #%>% st_set_crs(4326)

# dataset = ArchGDAL.read("MySQL:maps;host=data.mayin.org;user=$(maps_user);password=$(maps_password)")