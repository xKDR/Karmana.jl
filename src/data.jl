using DBInterface, MySQL


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
# setup
# maps_user = get(ENV, "MAPS_USER", "invalid")
# maps_password = get(ENV, "MAPS_PASSWORD", "invalid")

# maps_user == "invalid" && @error("The environment variable `MAPS_USER` was not found.  It must be provided in order to access the database.")
# maps_password == "invalid" && @error("The environment variable `MAPS_PASSWORD` was not found.  It must be provided in order to access the database.")

# admin_level = :District

# # getting the data
# # connection = DBInterface.connect(MySQL.Connection, "data.mayin.org", maps_user, maps_password)
# # use ArchGDAL

# archgdal_query_string = "MySQL:maps,host=data.mayin.org,user=$(maps_user),password=$(maps_password)"
# aggregation_layer = if admin_level == :State
#     "states"
# elseif admin_level == :HR
#     "homogeneous_regions"
# elseif admin_level == :District
#     "districts_2011"
# else
#     @error "The admin level $admin_level was not recognized; it must be `:State`, `:HR`, or `:District`."
# end

# read_the_map = st_read(dsn=dsn_for_maps, layer  = aggregation.layer)
# map_with_crs = read_the_map #%>% st_set_crs(4326)

# dataset = ArchGDAL.read(archgdal_query_string)