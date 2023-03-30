############################################################
#                         Parsers                          #
############################################################


# read lat-long strings from the CMIE Capex database 

"""
    latlong_string_to_points(latlong_string)

Parses a string of the form `lat1,long1 : lat2,long2 : lat3,long3 : ...` 
and returns a Vector of Point2e which define points as (long, lat).  

Is robust to cutoff errors and other potential issues.
"""
function latlong_string_to_points(latlong_string::AbstractString)

    points = Point2{Float64}[]

    pointstrings = split(latlong_string, ":")

    isempty(pointstrings) && return []

    for pointstring in pointstrings
        point = split(pointstring, ",")
        if length(point) ≤ 1 || length(point) > 2 || any(isempty.(point))
            continue
        else
            push!(points, Point2{Float64}(parse(Float64, strip(point[2])), parse(Float64, strip(point[1]))))
        end
    end

    return points

end

"""
    points_weights(latlong_strings::Vector{:< AbstractString}, costs::Vector{<: Real})

Parses strings of the form `lat1,long1 : lat2,long2 : lat3,long3 : ...` 
and returns a Vector of Point2e which define points as (long, lat), as well as
a vector of weights per point.  If the string has more than one point defined, 
the weight is spread across all `n` points such that each point has a weight of `cost[i]/n`.

Returns (::Vector{Point2e}, ::Vector{<: Real}).
    

!!! note
    This format of data is often found in CMIE capex location data.
"""
function points_weights(latlong_strings, costs)
    @assert length(latlong_strings) == length(costs)

    points = Vector{Point2{Float64}}()
    weights = Vector{Float64}()

    sizehint!(points, length(latlong_strings))
    sizehint!(weights, length(latlong_strings))

    for (latlong_string, cost) in zip(latlong_strings, costs)
        parsed_points = latlong_string_to_points(latlong_string)
        if length(parsed_points) == 1
            push!(points, parsed_points[1])
            push!(weights, cost)
        elseif length(parsed_points) > 1
            append!(points, parsed_points)
            append!(weights, fill(cost/length(parsed_points), length(parsed_points)))
        end
    end

    return points, weights
end


############################################################
#                     Geographic utils                     #
############################################################

########################################
#       Easy geodetic solutions        #
########################################

"""
    target_point(lon, lat, azimuth, arclength; geodesic = Proj.geod_geodesic(6378137, 1/298.257223563))

Returns a `Makie.Point2f` which represents the point at `arclength` metres from `lon`, `lat` in the direction of `azimuth`.
Basically a thin wrapper around Proj's GeographicLib `geod_directline`.

```jldoctest
julia> target_point(0, 0, 0, 0)
2-element Point2{Float64} with indices SOneTo(2):
 0.0
 0.0
````
"""
function target_point(lon, lat, azimuth, arclength; geodesic = Proj.geod_geodesic(6378137, 1/298.257223563))
    direct_line = Proj.geod_directline(geodesic, lat, lon, azimuth, arclength)
    lat, lon, azi = Proj.geod_position(direct_line, arclength)
    return Makie.Point2{Float64}(lon, lat)
end


"""
    get_geodetic_circle(lon, lat, radius; npoints = 100, geodesic = Proj.geod_geodesic(6378137, 1/298.257223563))

Returns a Vector of Makie.Point2f which represent a circle of radius `radius` centered at `lon`, `lat`, computed in geodetic coordinates.

`lon` and `lat` are in degrees, `radius` is in metres.

!!! note Performance
    Because this calls out to C, it's a bit slower than I'd like it to be, but not by much.  100 points takes about 28ms on my machine, a souped up Macbook Pro M1.

## Making annular rings

To create an annular ring, it's sufficient to say:
```julia
lon, lat = 72, 19
inner_radius = 1000
outer_radius = 10000
annular_polygon = GeometryBasics.Polygon(
        get_geodetic_circle(lon, lat, outer_radius), 
        [reverse(get_geodetic_circle(lon, lat, inner_radius))] # note the `reverse` here - this is for the intersection fill rule.
)
```
"""
function get_geodetic_circle(lon, lat, radius; npoints = 100, geodesic = Proj.geod_geodesic(6378137, 1/298.257223563))
    return [target_point(lon, lat, azi, radius; geodesic = geodesic) for azi in LinRange(0, 360, npoints)]
end

########################################
#         Manual line widening         #
########################################


"""
    line_to_geodetic_width_poly(line::Vector{<: Point2}, width; geodesic = Proj.geod_geodesic(6378137, 1/298.257223563))

Returns a `Vector{Point2{Float64}}` which represents a polygon which is `width` metres wide, and follows the path of `line`.

This is mostly useful for tracing wide lines on Raster maps.

Fundamentally, you can think of this function as creating a polygon from a line, with a specified width.  There's no interpolation, though - 
if you want interpolation, pass an interpolated vector of points in.
"""
function line_to_geodetic_width_poly(line::Vector{<: Point2}, width; geodesic = Proj.geod_geodesic(6378137, 1/298.257223563))
    # TODO: still some issues with this function, especially in highly irregular Lines
    # but for smoothish lines it should be fine! 
    top_points = Vector{Point2{Float64}}(undef, length(line))
    bottom_points = Vector{Point2{Float64}}(undef, length(line))

    for i in 1:(length(line) - 1)
        # first, compute the local azimuth on that line segment
        slope_in_degrees = atan((line[i + 1] .- line[i])...) / π * 180 # Proj and GeographicLib assume azimuth in degrees, watch out for this.
        top_points[i] = target_point(line[i]..., slope_in_degrees + 90, width / 2; geodesic = geodesic)
        bottom_points[i] = target_point(line[i]..., slope_in_degrees - 90, width / 2; geodesic = geodesic)
    end

    # fill in the last points
    last_slope = atan((line[end] .- line[end - 1])...) / π * 180
    top_points[end] = target_point(line[end]..., last_slope + 90, width / 2; geodesic = geodesic)
    bottom_points[end] = target_point(line[end]..., last_slope - 90, width / 2; geodesic = geodesic)

    return vcat(top_points, reverse(bottom_points))
end

########################################
#       Annular rings on rasters       #
########################################

"""
    annular_ring(f, source::Raster, lon, lat, outer_radius, inner_radius; pass_mask_size = false)

Returns the result of applying `f` to the subset of `source` which is masked by the annular ring defined by `lon`, `lat`, `outer_radius`, `inner_radius`.
The annular ring is constructed in geodetic space, i.e., distance is physically preserved.

`source` may be a 2D raster (in which case this function returns a value), or a 3D RasterStack or a RasterSeries of 2D rasters, in which case this function returns a `Vector` of values.

## Arguments
- `f` is a function which takes a `Raster` and returns a value.  This is the function which will be applied to the subset of `source` which is masked by the constructed annular ring. The result of `f` is returned.
- `source` is a `Raster` which will be masked by the annular ring.  This can be 2D, in which case `annular_ring` will return a single value, or 3D, in which case `annular_ring` will return a `Vector` of values.
- `lon`, `lat` are the coordinates of the centre of the annular ring, in degrees.
- `outer_radius` and `inner_radius` are the outer and inner radii of the annular ring, in metres.

- `pass_mask_size` determines whether to pass a second argument to `f` containing the number of points in the mask.  This is useful if you are taking statistical measures.

## How it works

- First, an annular ring polygon is created (in geodetic space, using [`get_geodetic_circle`](@ref)).
- Next, the extent of the annular ring polygon is computed, and the `source` raster is subsetted to that extent.  This is for efficiency, and so that the minimum possible number of multiplications are performed.
- The annular ring polygon is rasterized, using `Rasters.boolmask`.
- The subsetted `source` raster is multiplied by the rasterized annular ring polygon.
- Finally, `f` is applied to the result of the multiplication.

"""
function annular_ring(f::F, source::Raster{T, 2}, lon, lat, outer_radius, inner_radius; pass_mask_size = false) where {F, T}
    annular_polygon = Makie.GeometryBasics.Polygon(
        get_geodetic_circle(lon, lat, outer_radius), 
        [reverse(get_geodetic_circle(lon, lat, inner_radius))] # note the `reverse` here - this is for the intersection fill rule.
    )
    extent = GeoInterface.extent(annular_polygon)
    examinable_raster = source[extent] # TODO: should this be replaced by `Rasters.crop(source, to = annular_polygon)`?
    rasterized_polygon = Rasters.boolmask(annular_polygon, to = examinable_raster)
    return if pass_mask_size
        mask_size = sum(rasterized_polygon)
        f(examinable_raster .* rasterized_polygon, mask_size)
    else
        f(examinable_raster .* rasterized_polygon)
    end
end

function annular_ring(f::F, source::Raster{T, 3}, lon, lat, outer_radius, inner_radius; pass_mask_size = false) where {F, T}
    annular_polygon = Makie.GeometryBasics.Polygon(
        get_geodetic_circle(lon, lat, outer_radius), 
        [reverse(get_geodetic_circle(lon, lat, inner_radius))] # note the `reverse` here - this is for the intersection fill rule.
    )
    extent = GeoInterface.extent(annular_polygon)
    examinable_raster = view(source, :, :, 1)[extent]
    rasterized_polygon = Rasters.boolmask(annular_polygon, to = examinable_raster)
    return if pass_mask_size
        mask_size = sum(rasterized_polygon)
        map((x, y) -> f(x .* y, mask_size), view.((examinable_raster,), :, :, 1:size(examinable_raster, 3)), rasterized_polygon)
    else
        map((x, y) -> f(x .* y), view.((examinable_raster,), :, :, 1:size(examinable_raster, 3)), rasterized_polygon)
    end
    # NOTE: to apply multithreading, replace `map` with e.g. `ThreadPools.qmap`
end

# TODO: this assumes the axes of all rasters in the series are the same!
function annular_ring(f::F, source::RasterSeries{<: Raster{T, 2}}, lon, lat, outer_radius, inner_radius; pass_mask_size = false) where {F, T}
    return annular_ring.(f, collect(source), lon, lat, outer_radius, inner_radius ; pass_mask_size)
end