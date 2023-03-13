# TODO: document this
"""
    prepare_page(
        paper_size::Union{Symbol, NTuple{2, <: Real}},
        qr_code_contents::String;
        landscape = false,
        padding = 3,
        logo = rotr90(FileIO.load(assetpath("logos", "XKDR_Logomark_RGB_White.jpg"))),
        logo_height = 40,
        logo_padding = 5,
        qr_code_height = 60,
        qr_code_padding = 10,
    )

"""
function prepare_page(
        paper_size::Union{Symbol, NTuple{2, <: Real}},
        qr_code_contents::String;
        landscape = false,
        padding = 3,
        logo = rotr90(FileIO.load(assetpath("logos", "XKDR_Logomark_RGB_White.jpg"))),
        logo_height = 40,
        logo_padding = 5,
        qr_code_height = 60,
        qr_code_padding = 10,
    )

    landscape = to_value(landscape)
    padding = to_value(padding)
    logo = to_value(logo)
    logo_height = to_value(logo_height)
    logo_padding = to_value(logo_padding)
    qr_code_height = to_value(qr_code_height)
    qr_code_padding = to_value(qr_code_padding)
    
    resolution = if paper_size isa Symbol
        if paper_size === :a4
            (595, 842)
        elseif paper_size === :a3
            (842, 1190)
        elseif paper_size === :a2
            (1190, 1684)
        elseif paper_size == :a1
            (1684, 2384)
        elseif paper_size == :a0
            (2384, 3368)
        else
            @warn("Paper size `$paper_size` is not known!  Defaulting to `:a4``.")
            (595, 842)
        end
    else # paper_size isa Tuple
        paper_size
    end

    paper_size isa Symbol && if landscape
        if resolution[1] < resolution[2]
            resolution = reverse(resolution)
        end
    else # portrait
        if resolution[1] > resolution[2]
            resolution = reverse(resolution)
        end
    end

    figure_padding = if padding isa NTuple{4, <: Real}
        convert.(Float32, padding)
    elseif padding isa Real
        Float32.((padding, padding, padding, padding))
    else
        Float32.((0,0,0,0))
    end

    # create the Figure

    fig = Figure(
        resolution = resolution,
        figure_padding = figure_padding,
    )

    # write the xkdr logo on the top left of the picture 

    # compute the width of the logo
    logo_width = logo_height * size(logo, 1) / size(logo, 2)

    # plot to the Figure's scene
    image!(
        fig.scene,
        (padding + logo_padding)..(logo_padding + logo_width + padding),
        @lift($(pixelarea(fig.scene)).widths[2] - logo_padding - logo_height - padding..($(pixelarea(fig.scene))).widths[2] - logo_padding - padding),
        logo;
        space = :pixel,
        interpolate = false
    )


    # now for the QR code

    # QR code comes on the bottom right, so we'll do that first.
    # The QR matrix has values of 'true' for white and 'false' for black, so we need to invert that as well.

    qr_code_matrix = QRCode.qrcode(qr_code_contents, QRCode.Quartile(); compact = true) .|> !

    # We prepare an LScene, but it is not placed in any layout; instead, it is placed directly onto the 
    # figure.  This allows us to avoid any layout issues, and have absolute control over placement.
    qr_code_plot = image!(
        fig.scene, 
        @lift(($(pixelarea(fig.scene)).widths[1] - qr_code_height - qr_code_padding - padding)..($(pixelarea(fig.scene)).widths[1] - qr_code_padding - padding)), 
        (qr_code_padding + padding)..(qr_code_padding + qr_code_height + padding), 
        rotr90(qr_code_matrix); 
        space = :pixel, 
        interpolate = false,
        visible = !(qr_code_height == 0),
    )

    return fig

end

"""
    create_page(paper_size, qr_code_link; landscape = automatic, naxes = 1, supertitle = "Title", description = "...", kwargs...)


Creates a figure of the specified size with the specified arguments, themed for XKDR.  Applies the appropriate paper size theme (`theme_a4`, `theme_a3`, etc.)

### Arguments
- `paper_size`: A symbol representing the desired paper size; can be `:a[0/1/2/3/4]`.  More planned.  In the future, you may also be able to pass a tuple.
- `qr_code_link`: The contents of the QR code shown at the bottom left of the page.  Must be a string.

### Keyword arguments
- `landscape = automatic`: Decides whether the figure should be in landscape or portrait mode.  If `automatic`, decides automatically.  To set this manually, set `landscape = true` or `landscape = false`.
- `naxes = 1`: The number of axes to create in the central grid.  Automatically laid out.  
- `axistitles = Makie.automatic`: The tities for each axis.  If set to `automatic`, they will be the positions of the axes in the layout.

### Returns

Returns a NamedTuple containing the following items:

- `figure`: The Figure in which everything is plotted.
- `supertitle`: The `Label` which serves as the figure's title.
- `axis_layout`: The GridLayout in which the axes are placed.
- `axes`: A `Matrix{Union{Axis, Nothing}}` which contains the axes which can be placed.  If `nrows * ncols > naxes`, then the remaining positions will be `nothing`.
- `description_layout`: The GridLayout in which the description is placed.  Has 3 columns and 1 row.  The description label is located in `description_layout[1, 1]`, and `[1, 3]` is reserved for a box representing the QR code.  You can plot a legend or colorbar in `description_layout[1, 2]`.
- `description_label`: The `Label` which holds the figure's description.

The items can be extracted from the named tuple as in the following example:
```julia
page = create_page(:a4, "https://xkdr.org")
page.figure
page.axes[i::Int, j::Int]
page.description_layout
page.description_label
...
```
"""
function create_page(
        paper_size::Union{Symbol, Tuple{Int, Int}},
        qr_code_link::String = "https://xkdr.org";
        landscape = Makie.automatic,
        naxes = 1,
        hideaxisdecorations = true,
        hideaxisspines = true,
        axisaspect = DataAspect(),
        padding = _best_padding(paper_size),
        supertitle = "Title",
        description = "Placeholder: This is a label which should describe your plot[s].",
        axistitles = Makie.automatic,
        theme_kwargs...
    )   

    # closest_paper_size = approx_paper_size(paper_size)

    if landscape == Makie.automatic
        if prod(naxes) > 1
            landscape = true
        else
            landscape = false
        end
    end

    axis_nrows, axis_ncols = compute_gridsize(naxes; landscape)
    if axistitles == Makie.automatic
        axistitles = [string(ind.I) for ind in vec(Base.permutedims(CartesianIndices((axis_nrows, axis_ncols))))]
    end

    paper_theme = paper_size_theme(paper_size)

    theme = merge(
        Attributes(theme_kwargs), 
        paper_theme, 
        Makie.current_default_theme(), 
        theme_xkdr()
    )

    with_theme(theme) do

        # Get the Figure's background color, then check it 
        bg_color = Makie.to_color(Makie.to_value(get(theme, :backgroundcolor, RGBf(1,1,1))))
        # convert the background color to HSL, then check luminance.
        if HSL(bg_color).l ≥ 0.4 || alpha(bg_color) ≤ 0.3# light theme
            xkdr_logo_image = rotr90(FileIO.load(assetpath("logos", "XKDR_Logomark_RGB_Full_Colour.png")))
            qr_code_colormap = [colorant"black", colorant"white"]
        else # dark theme
            xkdr_logo_image = rotr90(FileIO.load(assetpath("logos", "XKDR_Logomark_White_Coral.png")))
            qr_code_colormap = Makie.to_color.([colorant"white", bg_color])
        end

        figure = prepare_page(
            paper_size, qr_code_link;
            logo = xkdr_logo_image,
            landscape, padding,
            get(theme, :Page, (;))...
        )

        # adjust the QR code for background color
        figure.scene.plots[2].colormap = qr_code_colormap
        supertitle_layout = GridLayout(figure[1, 1], 1, 3; tellheight = true, tellwidth = false)
        # first, create the supertitle
        supertitle = Label(
            supertitle_layout[1, 2];
            theme.Supertitle...,
            text = supertitle,
            tellwidth = false,
        )

        # in order to ensure that the supertitle never crosses the logo, we can add a box of zero height
        logo_avoidance_box_left = Box(supertitle_layout[1, 1];
            strokevisible = false,
            color = :transparent,
            tellwidth = true,
            tellheight = false,
            width = lift(figure.scene.plots[1].input_args[1], figure.scene.plots[1].input_args[2]) do logo_x_extents, logo_y_extents
                Fixed((logo_x_extents.right - logo_x_extents.left) + 2 * padding)
            end
        )
        logo_avoidance_box_right = Box(supertitle_layout[1, 3];
            strokevisible = false,
            color = :transparent,
            tellwidth = true,
            tellheight = false,
            width = lift(figure.scene.plots[1].input_args[1], figure.scene.plots[1].input_args[2]) do logo_x_extents, logo_y_extents
                Fixed((logo_x_extents.right - logo_x_extents.left) + 2 * padding)
            end
        )

        # create a sub grid layout in which all the axes will lie

        axis_layout = GridLayout(figure[2, 1], axis_nrows, axis_ncols)

        # create a matrix to hold the axes, nothing means there is no axis there
        axes = Matrix{Union{Makie.Axis, Nothing}}(undef, axis_nrows, axis_ncols)
        axes .= nothing

        _stop = false

        for i in 1:axis_nrows
            for j in 1:axis_ncols
                if (i-1) * axis_ncols + j > prod(naxes)
                    _stop = true
                    break
                else
                    axes[i, j] = Axis(axis_layout[i, j]; title = axistitles[j + (i-1) * axis_ncols], aspect = axisaspect)
                    hideaxisdecorations && hidedecorations!(axes[i, j])
                    hideaxisspines && hidespines!(axes[i, j])
                end
            end
            _stop && break # break if we have finished drawing all plots.
        end

        # create the description layout
        description_layout = GridLayout(figure[4, 1], 1, 3)

        qr_code_plot = figure.scene.plots[2]

        # the rightmost item is just a `Box` which makes sure the QR code is avoided.
        qr_avoidance_box = Box(
            description_layout[1, 3];
            strokevisible = false,
            color = :transparent,
            tellwidth = true,
            tellheight = false,
            width = lift(qr_code_plot.input_args[1], qr_code_plot.input_args[2]) do qr_x_extents, qr_y_extents
                Fixed((qr_x_extents.right - qr_x_extents.left) + 2 * padding)
            end
        )

        # now, we create the description label
        description_label = Label(
            description_layout[1, 1];
            theme.DescriptionLabel..., 
            text = description,
        )

        # set the max size we want the colorbar to be

        colsize!(description_layout, 2, Relative(0.3))


        # in order to make sure that the description layout takes the minimum
        # amount of space, we need to add a zero-width row to the layout.
        # This basically just ensures that the description items don't "float up".
        rowsize!(figure.layout, 3, 0)

        return (; figure, supertitle, axis_layout, axes, description_layout, description_label)
    end
    
end

# Override Base.display for our returned NamedTuple,
# for user convenience.
function Base.display(page::NamedTuple{(:figure, :supertitle, :axis_layout, :axes, :description_layout, :description_label)})
    Base.display(page.figure)
end