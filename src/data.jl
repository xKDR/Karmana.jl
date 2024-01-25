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

"""
    maps_db_connection(user = ENV["MAPS_USER"], password = ENV["MAPS_PASSWORD"])::DBInterface.Connection

Returns a connection to the `maps` database on data.mayin.org, which must be closed by `DBInterface.close!`.
"""
function maps_db_connection(user = get(ENV, "MAPS_USER", "invalid"), password = get(ENV, "MAPS_PASSWORD", "invalid"))

    user == "invalid" && error("The environment variable `MAPS_USER` was not found.  It must be provided in order to access the database.")
    password == "invalid" && error("The environment variable `MAPS_PASSWORD` was not found.  It must be provided in order to access the database.")

    return DBInterface.connect(MySQL.Connection, "data.mayin.org", user, password, db = "maps")
end

"""
    do_geoquery(connection, layer; geometrycols = ["SHAPE"])::DataFrame

Performs a `SELECT * FROM \$layer` operation on the database which `connection` points to,
but all `geometrycols` are additionally wrapped in `ST_AsBinary`, which converts geometries
from SQL format (which has an extra CRS indicator) to well known binary (WKB) format,
which is parseable by e.g. ArchGDAL (or WellKnownGeometry.jl, which is substantially slower).

WKB columns are given the suffix `_wkb` to differentiate them from the original columns.  

Results are returned as a DataFrame.
"""
function do_geoquery(connection, layer; geometrycols = ["SHAPE"]) 
    result = DataFrame(DBInterface.execute(connection, "SELECT *, $(join("ST_AsBinary(" .* geometrycols .* ") as " .* geometrycols .* "_wkb", ", ", "")) FROM $layer"))
    DataFrames.select!(result, Not(geometrycols...))
    return result
end

"""
    shape_wkb_to_module_geom!(mod::Module, table::DataFrame; new_colname = :geometry, wkb_colname = :SHAPE_wkb)

Converts the geometries in `old_colname` (in WKB format as `eltype(old_colanme) = Vector{UInt8}`) into geometries of the 
provided module `mod`.  This goes through ArchGDAL instead of being pure-Julia with WellKnownGeometry, since that's faster.
"""
function shape_wkb_to_module_geom!(mod::Module, table::DataFrame; new_colname = :geometry, wkb_colname = :SHAPE_wkb)
    archgdal_geoms = ArchGDAL.fromWKB.(table[!, wkb_colname])
    table[!, new_colname] = GeoInterface.convert.((mod,), archgdal_geoms)
    DataFrames.select!(table, Not(wkb_colname))
    return table
end

"""
    state_hr_district_dfs()

A wrapper function which materializes the state, HR, and district dataframes in Julia,
by connecting to the `maps` database of `data.mayin.org`.  

Returns 3 DataFrames `(state_table, hr_table, district_table)` which all have columns `:geometry`
populated by GeometryBasics geometry, which is suitable for plotting.
"""
function state_hr_district_dfs()
    # connect to the database
    connection = maps_db_connection()
    # get the CRS (if on another DB)
    spatial_ref_df = DBInterface.execute(connection, "SELECT * from spatial_ref_sys") |> DataFrame
    db_crs = spatial_ref_df.SRTEXT[begin] # TODO: use this when converting.
    district_table = do_geoquery(connection,"districts_states_hr" )
    shape_wkb_to_module_geom!(GeometryBasics, district_table)
    dropmissing!(district_table)
    DBInterface.close!(connection)

    #return state_table, hr_table, district_table, my_table
    return district_table

end

# example code in R whose functionality this replicates
# read_the_map = st_read(dsn=dsn_for_maps, layer  = aggregation.layer)

# TODO: figure out why this doesn't work
# dataset = ArchGDAL.read("MySQL:maps;host=data.mayin.org;user=$(maps_user);password=$(maps_password)")
# my name is siddhant

