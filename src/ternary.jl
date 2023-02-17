
# to re-generate the colormaps, do the following:

const _Rmap_default = Ref{Vector{RGBf}}(RGBf[])
const _Gmap_default = Ref{Vector{RGBf}}(RGBf[])
const _Bmap_default = Ref{Vector{RGBf}}(RGBf[])

using Makie: Colors, PlotUtils

"""
    mutable struct TernaryColormap

Represents a ternary colormap.  

Construct by passing three `PlotUtils.ColorGradients` or objects which can be converted to them (symbols, strings).

Call by using the ternary colormap object (`tmap`) as a callable - methods include `tmap(x, y, z)` or `tmap(Point3f(...))` or `tmap((x, y, z))`.  Returns an `RGBAf` object when called.

Visualize by calling `Makie.plot(tmap)`.
"""
mutable struct TernaryColormap
    "Holds the map from x-value to color."
    xmap::Makie.PlotUtils.ColorGradient
    "Holds the map from y-value to color."
    ymap::Makie.PlotUtils.ColorGradient
    "Holds the map from z-value to color."
    zmap::Makie.PlotUtils.ColorGradient
end

function TernaryColormap(xmap, ymap, zmap)
    return TernaryColormap(PlotUtils.cgrad(xmap), PlotUtils.cgrad(ymap), PlotUtils.cgrad(zmap))
end

# default colormaps - perceptual r/g/b
function TernaryColormap()
    return TernaryColormap(
        csv_to_cgrad(Karmana.assetpath("colormaps", "ternary", "perceptual_red.csv")),
        csv_to_cgrad(Karmana.assetpath("colormaps", "ternary", "perceptual_green.csv")),
        csv_to_cgrad(Karmana.assetpath("colormaps", "ternary", "perceptual_blue.csv")),
    )
end


# how to actually call this thing
function (cmap::TernaryColormap)(x, y, z)
    # handle colors outside plane
    if x < 0f0 || y < 0f0 || z < 0f0 || !isapprox(x + y + z, 1)
        return get(cmap.xmap, NaN)
    end
    # add all three colors together to get the correct color
    return_color = get(cmap.xmap, x) + get(cmap.ymap, y) + get(cmap.zmap, z)
    return RGBAf(
        Colors.clamp01(Colors.red(return_color)),
        Colors.clamp01(Colors.green(return_color)),
        Colors.clamp01(Colors.blue(return_color)),
        Colors.clamp01(Colors.alpha(return_color))
    )
end

(cmap::TernaryColormap)(point::Makie.VecTypes{3}) = cmap(point...)

function (cmap::TernaryColormap)(point::AbstractVector{<: Real})
    @assert length(point) == 3 "You must pass a length 3 vector to obtain a color from a ternary colormap.  The vector passed in had length $(length(point))."
    return cmap(point...)
end


# Quick visualization utilities, so you can see your colormap !
Makie.plottype(::TernaryColormap) = Makie.Image

function Makie.convert_arguments(::Type{<: Makie.Image}, tmap::TernaryColormap)
    nsteps = 500
    xmin, xmax = tmap.xmap.values[1], tmap.xmap.values[end]
    ymin, ymax = tmap.ymap.values[1], tmap.ymap.values[end]
    zmin, zmax = tmap.zmap.values[1], tmap.zmap.values[end]

    xs = LinRange(0, 1, nsteps)
    ys = LinRange(0, 1, nsteps)
    colors = map(tmap, TernaryDiagrams.from_cart_to_bary.(xs, ys'))

    return (xs, ys, colors)
end



# hijack the colormap interface for ternary colormaps
# TODO this doesn't really work since you can't pass this to intensity
# better to just use `plot(...; color = tmap.(values))` instead. 
# function Makie.color_and_colormap!(plot, colors::AbstractArray{<: Makie.VecTypes{3, <: Real}})
#     @assert plot.colormap[] isa TernaryColormap "You can only use ternary colormaps if your color is an Array of 3-dimensional values."
#     # there can technically be low and high clips, but what does that really mean?  just invalid values?

#     plot.color[] = plot.colormap[].(colors)
# end