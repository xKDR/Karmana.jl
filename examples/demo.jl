# Preliminary setup
# Activate the correct environment
using Pkg; Pkg.activate(@__DIR__)
# Set an environment variable which tells Karmana.jl, when loaded, to utilize the 
# `maps/DATA` india shapefile, instead of having it get that from the database.
ENV["KARMANA_DISTRICT_SHAPEFILE"] = joinpath(dirname(dirname(@__DIR__)), "DATA", "INDIA_SHAPEFILES", "Districts_States_HR", "2011_Districts_State_HR.shp")


using Karmana
using Makie, CairoMakie # backend for Makie.jl - necessary if you want to save a plot
using Makie.Colors 
# # Basic usage for Karmana
# Before you run this code, make sure that you have 
# read the Makie tutorial at docs.makie.org first!

# ## Creating a page
# First, create a page of the appropriate size with xKDR poster formatting
# using the `create_page` function.  This returns a NamedTuple with a figure,
# some axes, and a customized layout.  
# You must provide the page size you want to the function, as a Symbol (:a4-:a0 are supported for now).
page = create_page(:a4)

# By default, the `create_page` function creates only one axis.  It returns all axes as a matrix, 
# so that it's easy and intuitive to refer to them in a grid.

# ## Plotting using `indiaoutline!`
# The `IndiaOutline` plot type was designed specifically for CPHS state, HR, or district level data,
# and automates a lot of the data munging you may have to do otherwise.
# You can call it in one of the following ways:
# - Provide an admin level `Symbol`, a vector of IDs for that admin level, and a vector of values for those IDs
# - Provide a DataFrame, its ID column as a symbol, and its value column as a symbol
# - Provide an 
# What we're doing below is the first option, which is also the most versatile.
# We're accessing 
outline_plt = indiaoutline!(
    page.axes[1, 1], 
    :HR,                      # admin level symbol
    [70, 71, 72, 73, 74, 75], # IDs
    rand(6);                  # values
    HR = (strokecolor = to_color(:blue),),
    colormap = :Reds
)
# Now, we display the page again (assuming you're using CairoMakie, graphs do not update interactively)

page

# You can alter the attributes of an `IndiaOutline` plot after the fact, using the standard Makie attribute updating syntax.
# For example, you can change the colormap like this:
outline_plt.plots[2].colormap[] = :Oranges

page

# You can also change the attributes of the `IndiaOutline` plot itself, like this:
# (note the nested attributes here, if you want to know more, read the docstring).

outline_plt.State.strokewidth[]    = 0.2 #* 2 * 2
outline_plt.HR.strokewidth[]       = 0.2 #* 2 * 2
outline_plt.HR.strokecolor[]       = to_color(:blue)
outline_plt.District.strokewidth[] = 0.1

page


# There's also a description, and you might note the space between that 
# and the QR code, which is another layout cell which you can use 
# for a legend, or a colorbar.  Here's how you can add a colorbar there (note that it should be horizontal):
cb = Colorbar(
    page.description_layout[1, 2], # this is the empty layout cell into which you can place a colorbar``
    outline_plt.plots[2].plots[1]; # this is the plot - TODO make this easier
    flipaxis = false,              # this keeps the colorbar's axis at the bottom
    vertical = false               # this sets the colorbar's orientation to be horizontal
)

page

# this is how to save a page object, if you want to
# `save("my_map.png", page.figure; px_per_unit = 3)`
# `save("my_map.pdf", page.figure; pt_per_unit = 1)`

# ## Using `create_page`
# Multiple axes default to landscape, but that 
# specific behaviour can be changed on the basis of paper size.

page = create_page(:a4; landscape = true)
# You can define a set number of axes, and they will be arranged in a grid.
page = create_page(:a4; naxes = 2)
# Alternatively, you can also define the number of rows and columns.
page = create_page(:a4; naxes = (2, 3))
# There are multiple options for paper size, ranging from a4 to a0.
page = create_page(:a3)


page = create_page(:a3; landscape = false, naxes = 4)
setproperty!.(page.axes, :aspect, (DataAspect(),))
indiaoutline!.(page.axes, (:State,), (:all,))
page

# The function is integrated well with Makie's themes,
# and we could make our own for e.g. BQ or BS, following their style.

# Any plots on this new page follow the theme with which it was created.

with_theme(theme_black()) do
    create_page(:a3)
end


# TODO: resurrect the `draw_boxes` function
# This is what the layout looks like:
# draw_boxes(page.figure.layout)
page.figure


# ## Handling raster data
# Most raster data in Julia is handled by the `Raster` type from the [`Rasters.jl`](github.com/rafaqz/Rasters.jl) package.
# Makie.jl supports plotting `Raster`s efficiently using the `heatmap` function; however, if you want to display your data
# in 3D, you can also use `surface!`.  

# First, we load `Rasters` (and `GeoInterface`, which is a common interface for vector data):
using Rasters, GeoInterface
# First, we extract India's bounding box (I could have hardcoded this, but was too lazy).

# This code merges all of the state geometries of India (including union territories) and 
# finds their bounding box.
india_bbox = GeoInterface.extent(Karmana.merge_polys(Karmana.state_df[].geometry))
# Now, we create a raster with 30x30 pixels, and fill it with a field of a known function.

# First, we create the field:
field = Makie.peaks(30) # this is essentially a convenience function which generates a matrix of data
# Then, we can create the raster, using `Rasters.X` and `Rasters.Y` to indicate dimensions.
mydims = (X(LinRange(india_bbox.X..., 30)), Y(LinRange(india_bbox.Y..., 30)))
india_raster = Raster(field, mydims)
# This is the raster.  We can plot it using `heatmap`, `surface`, or even `contour`!
# Any Makie plot type which is `SurfaceLike()` will work.

# First, let's make sure that the raster looks the same as the original data:
fig, ax1, plt1 = surface(field; axis = (title = "Original data", type = Axis3))
ax2, plt2 = surface(fig[1, 2], india_raster; axis = (title = "Raster", type = Axis3))
fig
# Hey, these look practically identical - except for the x and y values on the left plot,
# which are actually the bounding box for India!

# Now, let's plot the raster using `heatmap`:
fig, ax, plt = heatmap(india_raster; axis = (title = "Heatmap", aspect = DataAspect()))
# Note the inclusion of `aspect = DataAspect()` in that `heatmap` call - this ensures
# that the pixels of the map reflect physical reality.
indiaoutline!(ax, :State, :all; merge_column = :st_nm, external_merge_column = :st_nm)
fig
# This is clearly unrealistic, but otherwise correct!


# TODOs:
# - [ ] Add a `draw_boxes` function to draw boxes around the layout cells
# - [ ] Change the raster example to use Rasters.jl data from BioClim.