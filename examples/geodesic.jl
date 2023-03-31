# Karmana's geodesic utilities

# This example explores some of the geodesic utilities which Karmana provides.

# A geodesic path is the shortest path from point A to point B on the surface of
# the Earth, taking into account its curvature.  It is the distance "as the crow flies".

using CairoMakie, Karmana

# ## Geodetic circles
# A "geodetic circle" is the locus of all points which are physically `radius` away from the center.

# Here's one around Mumbai:
initial_line = Karmana.get_geodetic_circle(72, 19, 9000) # 9km radius around Mumbai
lines(initial_line; axis = (; aspect = DataAspect()))

# This is another geodetic circle at a 20km radius around Mumbai.

fig, ax, circ_plt = lines(Karmana.get_geodetic_circle(72, 50, 20_000); linewidth = 2, axis = (; aspect = DataAspect()))
cent_plot = scatter!(ax, [Point2f(72, 50)])
fig

# Note the difference in the physical width of the two circles.  
# This is because the Earth is not a perfect sphere, but is slightly 
# flattened at the poles.

# ## Geodetic width polylines

# Karmana can geodetically expand lines to polygons along the same path as the line,
# with some fixed width. 
poly_line = Karmana.line_to_geodetic_width_poly(Point2f.(LinRange(0, 12, 100), 50 .* sin.(LinRange(0, 12, 100))), 20_000)
poly(poly_line; aspect = DataAspect())

# Because of the aspect ratio of the plot, the polygon is thin when going horizontally, and thick when going vertically.

# ## Annular rings

# Rasters.rasterize works on this polygon!  This is an "annular ring", i.e.,
# a circle with a hole in the middle.
annular_polygon = Makie.GeometryBasics.Polygon(
    Karmana.get_geodetic_circle(72, 50, 90_000), 
    [reverse(Karmana.get_geodetic_circle(72, 50, 20_000))] # note the `reverse` here - this is for the intersection fill rule.
)

poly(annular_polygon; axis = (; aspect = DataAspect()))

# You can see how the ring was warped because of its latitude.

# These are the building blocks for the annular ring and geodetic utilities which Karmana exposes.
# ```julia
# using CSV, DataFrames, Statistics
#
#
# # Let's get some interesting data, you could put nightlights here as well.
#
# xs, ys = dims(nightlights_raster)   
# nightlights_bbox = Makie.BBox(extrema(xs)..., extrema(ys)...)
#
# city_dataset = CSV.read("/Users/anshul/Downloads/simplemaps_worldcities_basicv1.75/worldcities.csv", DataFrame)
#
# lats, lons = city_dataset[!, :lat], city_dataset[!, :lng]
#
# india_cities = dropmissing(city_dataset[in.(Point2f.(lons, lats), (nightlights_bbox,)), :])
# sort!(india_cities, :population; order = Base.Reverse)
#
# # Top 8 cities in India by population
# india_cities.city_positions = Point2{Float64}.(india_cities[!, :lng], india_cities[!, :lat])
#
# one_light_from_ring = Karmana.annular_ring.(Statistics.mean, view(nightlights_raster, :, :, 1), india_cities.city_positions[1]... #= lon, lat=#, 15000, 3000)
#
# lights_from_ring = Karmana.annular_ring.(Statistics.mean, nightlights_raster, india_cities.city_positions[1]..., 15000, 3000)
#
# # plot
#
# f, a, p = lines(lights_from_ring, label = "Mean radiance", axis = (; title = "Mean nighttime light radiance around Mumbai over time", xlabel = "Time (months)", ylabel = "Radiance"))
# axislegend(a, position = :lt)
# a.title = "Mean nighttime light radiance around Delhi over time"
# f
# ```