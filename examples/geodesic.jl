# Exploring the geodesic utilities that Karmana provides

using CairoMakie, Karmana


# Geodetic circles - the locus of all points which are physically `radius` away from the center
initial_line = Karmana.get_geodetic_circle(72, 50, 9000)
lines(initial_line; axis = (; aspect = DataAspect()))

#

fig, ax, circ_plt = lines(Karmana.get_geodetic_circle(72, 50, 20000); linewidth = 2, axis = (; aspect = DataAspect()))
cent_plot = scatter!(ax, [Point2f(72, 50)])
fig

# Geodetically expanding lines - equal physical width lines
poly_line = Karmana.line_to_geodetic_width_poly(Point2f.(LinRange(0, 12, 100), 50 .* sin.(LinRange(0, 12, 100))), 20_000)

poly(poly_line; aspect = DataAspect())


# Rasters.rasterize works on this polygon!
annular_polygon = Makie.GeometryBasics.Polygon(
    Karmana.get_geodetic_circle(72, 50, 90000), 
    [reverse(Karmana.get_geodetic_circle(72, 50, 20000))] # note the `reverse` here - this is for the intersection fill rule.
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