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
#
p.colorrange[] = crange
f
# Now that makes a lot more sense.

# To plot the heatmap, we'll want to crop the BioClim raster to the extent of India. Here's how we can do that:
india_border = Karmana.merge_polys(Karmana.state_df[].geometry)
masked_india_raster = Rasters.mask(worldclim_bioclim_raster[:, :, 1], with = india_border)[GeoInterface.extent(india_border)]
heatmap(masked_india_raster; colorrange = crange)
# Note how the raster is now cropped to the extent of India.  

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

# But first, let's plot!


precipitation_plot = heatmap!(page.axes[1, 1], masked_india_raster; colorrange = crange)
india_outline_plot = indiaoutline!(page.axes[1, 2], :State, 1:36, rand(36); colormap = :Oranges)

page.figure

# The poster is optimized for printing, so there's a lot of whitespace (1 inch) at the border.

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

# Let's also add a colorbar, to represent the color scale of the precipitation plot:
cb = Colorbar(page.description_layout[1, 2], precipitation_plot; label = "Precip. (mm)", flipaxis = true)
page.figure

page.description_label.alignmode[] = Outside()

page.figure

# Finally, we can change the titles of the axes, and similarly any other attribute:
page.axes[1, 1].title = "Precipitation"
page.axes[1, 2].title = "Population (fake)"
page.figure
# We can also add a legend, to represent the colors of the states:  

leg = Legend(
    page.description_layout[1, 2, Right()], # this is placed as a protrusion in cell `[1, 2]`.
    [ # elements
        PolyElement(color = cgrad(:Oranges)[0.125]),
        PolyElement(color = cgrad(:Oranges)[0.25 + 0.125]),
        PolyElement(color = cgrad(:Oranges)[0.5 + 0.125]),
        PolyElement(color = cgrad(:Oranges)[0.75 + 0.125]),
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
leg.alignmode = Outside()

page.figure