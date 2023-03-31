# # Creating a poster using Karmana

using Karmana, Rasters, CairoMakie, GeoInterface

# ## Getting the data

# We'll get some real-world data to plot, since this isn't as interesting otherwise.

# ### Raster data

# Let's get some raster data to plot, in this case the precipitation data from the WorldClim project.

worldclim_bioclim_raster = Raster(WorldClim{BioClim}, :BIO13)

# This looks like:
f, a, p = heatmap(worldclim_bioclim_raster; axis = (; aspect = DataAspect()))
a.title = "Precipitation in wettest month"
cb = Colorbar(f[1, 2], p; label = "Precip. (mm)")
f
# That doesn't tell us much - everything is blue!  
# Let's increase the contrast, by setting a different color range:
crange = Makie.PlotUtils.zscale(p[3][], 5000; contrast = 0.1)
# This is a pretty useful function which you can use when your dataset has a lot of outliers!
p.colorrange[] = crange
f
# Now that makes a lot more sense.  
# We can see how areas in South America, East Africa, 
# and South and Southeast Asia are all pretty rainy.

# To plot the heatmap, we'll want to crop the BioClim raster to the extent of India. Here's how we can do that:
india_border = Karmana.merge_polys(Karmana.state_df[].geometry)
masked_india_raster = Rasters.mask(worldclim_bioclim_raster[:, :, 1], with = india_border)[GeoInterface.extent(india_border)]
heatmap(masked_india_raster; colorrange = crange, axis = (; aspect = DataAspect()))
# Note how the raster is now cropped to the extent of India.  

# ### State-level data

# Since this is not running with access to CPHS...we'll just make something up!
fake_population = rand(size(Karmana.state_df[], 1))
state_ids = Karmana.state_df[].st_cen_cd

# ## Creating the poster

# We start by creating a page; we want this poster to be a3 sized and have 2 axes.

page = create_page(
    :a3,
    "https://xkdr.github.io/Karmana.jl/dev", # the QR code,
    naxes = 2,
    landscape = true
)
page.figure
# While you can provide the title and the description as keywords to `create_page`, we'll instead set them manually, to show how it can be done.

# ### Plotting to the figure

# But first, let's plot!

precipitation_plot = heatmap!(page.axes[1, 1], masked_india_raster; colorrange = crange)
india_outline_plot = indiaoutline!(page.axes[1, 2], :State, state_ids, fake_population; colormap = :Oranges)

page.figure

# The poster is optimized for printing, so there's a lot of whitespace (1 inch) at the border.

# ### Configuring figure attributes
# In many other plotting packages, if you want to configure a figure, you have to do it at the time you create it.
# This is not the case in Makie - you can configure the figure's attributes at any time.  

# This means we don't have to worry about the initial settings too much, 
# and we can configure the figure as we go.

# Let's configure the title now!  The title is a `Label` object, which we can access through `page.supertitle`:
page.supertitle

# From there, it's a standard label, so we can set its attributes:
page.supertitle.text = "Does precipitation impact population?"
page.figure

# The description is also a label, accessible via `page.description_label`:
page.description_label.text = "This answers all of your burning questions - by raining on them!"
page.figure

# The description label is in the bottom row, which contains a layout called `page.description_layout`:
page.description_layout

# Finally, we can change the titles of the axes, and similarly any other axis attribute:
page.axes[1, 1].title = "Precipitation"
page.axes[1, 2].title = "Population (fake)"
page.figure

# ### Creating a colorbar

# Let's also add a colorbar, to represent the color scale of the precipitation plot:
cb = Colorbar(page.description_layout[1, 2], precipitation_plot; label = "Precip. (mm)", flipaxis = true, tickalign = 1)
page.figure

page.description_label.alignmode[] = Outside()

page.figure

# ### Creating a legend

# We can also add a legend, to represent the colors of the states.
# We'll place this in the right side of the layout cell which currently 
# holds the colorbar.

# To create this legend, we'll use `PolyElements` to represent discrete colors.

leg = Legend(
    page.description_layout[1, 2, Right()], # this is placed as a protrusion in cell `[1, 2]`.
    [ # elements
        PolyElement(; color) for color in cgrad(:Oranges)[0.125:0.25:1]
    ],
    [ # labels
        "0-25%",
        "25-50%",
        "50-75%",
        "75-100%",
    ],
    "Population"; # title
    orientation = :vertical,
    nbanks = 1,
    labelsize = 10,
    framevisible = false,
)

# This legend is protruding a bit, let's change how it's aligned vertically:
leg.valign = :bottom
page.figure

# This made the legend have its bottom point aligned to the row's bottom.

# The bottom of the legend is still a little above the colorbar, though - but we can fix that,
# by changing the padding of the legend:
leg.padding

# This is in a (left, right, bottom, top) format, so
leg.padding[] = (leg.padding[][1], leg.padding[][2], 0f0, leg.padding[][4])
page.figure

# ## Moving things around in the layout

# You can move objects around the layout very easily.  Let's swap the colorbar with the description:
page.description_layout[1, 1] = cb
page.description_layout[1, 2] = page.description_label
page.figure
# This is a pretty cool thing, but the figure needs some tuning.
colsize!(page.description_layout, 2, Auto())
page.figure
# Let's also spread the elements out evenly.  The way to do this is to add another column to the `description_layout`:
page.description_layout[1, 4] = contents(page.description_layout[1, 3])[1]
page.description_layout[1, 3] = leg
page.figure

# Let's also align the description to the bottom of the page,
page.description_label.valign[] = :bottom
page.figure

# This isn't the most elegant solution, but you can have a colorbar label on the opposite side to the ticks.

# We can do this by putting the colorbar into a new gridlayout, and the label below that:

colorbar_layout = GridLayout(page.description_layout[1, 1])
colorbar_layout[1, 1] = cb
cb.label = ""
cb_label = Label(colorbar_layout[2, 1], "Precip. (mm)", font = :bold)
page.figure

# Oops!  The label has squashed our colorbar.  Let's fix that, and decrease the spacing:
cb_label.tellwidth = false
cb_label.tellheight = true
rowgap!(colorbar_layout, 1, 10)
page.figure

# ## Saving posters

# Generally, you will get the best output if you save your poster as a PDF,
# since text etc. will be vectorized.

# You can do this by:
# ```julia
# save("poster.pdf", page.figure; pt_per_unit = 1)
# ```

# Here, the `pt_per_unit` argument enforces that the paper size must be equal to
# the figure's resolution.  If it is not, then 1 pt is treated as equivalent to
# 0.75 px, which is the default scaling for the web.

# That being said, large images and complex polygons with lots of points
# can cause the file size to increase quite a bit, up to twenty megabytes
# for only one `IndiaOutline` plot.

# In order to reduce the file size, you can rasterize the plot 
# (this only works with the CairoMakie backend).

# This is done by setting the `rasterize` attribute of the plot to some number,
# which controls the pixel density.  If the rasterized plot has a pixel size of `(n, n)`,
# then with `plot.rasterize = i`, the rasterized image which "replaces" the plot in the final PDF
# will have a resolution of `(n*i, n*i)`.

india_outline_plot.rasterize = 3

# `save("poster.pdf", page.figure; pt_per_unit = 1)`

# This reduces the file size to about 1 MB.  You can set this to any 
# stereotypical 