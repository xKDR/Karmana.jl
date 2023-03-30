using Rasters, Karmana, CairoMakie

# Let's get some interesting data, you could put nightlights here as well.

# Since we have to download the data on the CI server, I'll restrict this analysis to Delhi.
delhi_lonlat = Point2f(77.1025, 28.7041) # from Wikipedia

# This should either be a 2D or 3D raster.
## nightlights_raster = view(Raster("/Users/anshul/Documents/Business/India/XKDR/code/maps/DATA/updated_india.nc"; lazy = true), :, :, 1, :)
# This is the MODIS 250m vegetation dataset, for the months of 2002
# We have to do some processing here, since we want a true 3D raster, 
# and not a 4D raster with a singleton 3rd dimension.
# First, download the raster as a RasterSeries.  This is basically a collection of rasters which is correctly hooked up with time indices, etc.
# This line downloads the data in a 50x50km box around Delhi, for all readings in 2022.
modis_series = RasterSeries(MODIS{MOD13Q1}, :NDVI; lat = delhi_lonlat[2], lon = delhi_lonlat[1], km_ab = 50, km_lr = 50, date = (Date(2022,1,1), Date(2022,12,1)))
# Let's see what one of these rasters looks like:
modis_series[1]
# Oops, this is a 3D raster!  We can fix that real quick:
modis_2d_series = RasterSeries(view.(modis_series, :, :, 1), dims(modis_series)...)
# We can actually concatenate these into a single raster, which we'll do here:
modis_raster = cat(modis_2d_series..., dims = dims(modis_2d_series)[1])
# We now have a proper 3D raster!  Let's do a quick animation to see how it looks:
fig, ax, hm = heatmap(modis_raster[:, :, 1], axis = (; aspect = DataAspect()))
cb = Colorbar(fig[1, 2], hm; label = "Vegetation index")
fig
# We can interpolate the RasterSeries for a better animation:
using DataInterpolations: QuadraticInterpolation
modis_interpolated = QuadraticInterpolation(modis_2d_series, Dates.value.(collect(dims(modis_2d_series)[1])))
modis_interpolated(Dates.value(Date(2022, 5, 1)))
# Let's make a video of this:
record(fig, "modis_vegetation_over_delhi.mp4", Date(2022, 1, 1):Day(1):Date(2022, 12, 31); framerate = 30) do date
    hm[3][] = Makie.convert_arguments(Makie.ContinuousSurface(), modis_interpolated(Dates.value(date)))[3]
    ax.title = string(date)
end
# ![](modis_vegetation_over_delhi.mp4)
# Now, for the annular ring!
# We can easily get the vegetation data over Delhi for a ring between 4 and 15 km from the center:
vegetation_series = Karmana.annular_ring(modis_2d_series, delhi_lonlat..., 15000, 4000; pass_mask_size = true) do raster, mask_size
    ## We can do some processing here, if we want to.
    ## For now, we just take the mean of all points in the mask.
    sum(raster) / mask_size
end
# This is what the timeseries looks like!
lines(Dates.value.(collect(dims(modis_2d_series)[1])) .- Dates.value(Date(2022, 1, 1)), vegetation_series; axis = (title = "Vegetation over time in Delhi", ylabel = "Mean vegetation index", xlabel = "Days since start of year"))

# For an encore, let's animate what we see in the annular ring.
fig, ax, hm = heatmap(modis_2d_series[1]; axis = (; aspect = DataAspect()))
record(fig, "modis_annular_rings.mp4", Date(2022, 1, 1):Day(1):Date(2022, 12, 31); framerate = 30) do date
    ax.title[] = string(date)
    Karmana.annular_ring(modis_interpolated(Dates.value(date)), delhi_lonlat..., 15000, 4000; pass_mask_size = false) do raster
        ## Here, we don't actually do any processing, just visualize the premultiplied raster!
        hm[3][] = Makie.convert_arguments(Makie.ContinuousSurface(), raster)[3]
    end
end