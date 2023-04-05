# # Ternary colormaps

using Karmana, CairoMakie, TernaryColormaps

# Ternary diagrams are plots on the plane ``x + y + z = 1``, in Cartesian space.

# A ternary colormap is a sampler which takes as input a coordinate for which ``x + y + z = 1``,
# and returns a color.   The color is specified by three color gradients, one for each of `x, y, z`.

# In Karmana, a ternary colormap is created by the [`TernaryColormap`](@ref) constructor, which has various keyword
# arguments that you can see in its documentation.


# Here's what a ternary colormap looks like:

fig = Figure()
ax, im = Karmana.TernaryColorlegend(fig[1, 1], TernaryColormap())
fig

# This is pretty cool, but some of the colors seem wrong.  Let's inspect the data:


fig = Figure()
ax = Axis(fig[1, 1]; aspect = AxisAspect(96/71))
hidedecorations!(ax); hidespines!(ax)
TernaryDiagrams.ternaryscatter!(ax, (getindex.(data, i) for i in 1:3)...; color = colors, markersize = 30)

ternaryaxis!(ax);

fig

# Any ternary colormap can be called like a function to return a color, as in `tmap(x, y, z)` or `tmap(::Point3)`, where `tmap` is a `TernaryColormap`.
# This handles NaNs and missings by setting their values to zero.

# ## Using ternary colormaps

# Let's say I have some (fake) survey data across India, with three responses: good, bad, and unsure.  Unsure is not actually in between good and bad, since it can mean a lot of things, so we want to incorporate it as a third variable.

# First, we create some random points:
random_data = rand(Point3f, 36)

f, a, p = scatter(random_data)

rotate_cam!(a.scene, π/6, π/6, 0, 0)

f

# Then, we project them onto the ``x+y+z=1`` plane (this is normalizing to the ``L_1`` norm, which is effectively what I said earlier - ensuring that the sum of ``x``, ``y``, and ``z`` is 1.)

using LinearAlgebra
data = LinearAlgebra.normalize.(random_data, 1)

scatter!(a, data; color = :red)
f

triplane = mesh!(a, Point3f[(0,0,1), (0, 1, 0), (1, 0, 0)]; color = (:blue, 0.5))
f

# Now, we can find the colors:

colors = tmap.(Point3f.(data))

# We can even plot this using the `indiaoutline` recipe, 
# which can take colors in place of values:

f, a, p = indiaoutline(:State, 1:36, colors; axis = (aspect = DataAspect(),))

# Let's also add a legend to this:

ta, ip = Karmana.TernaryColorlegend(f[1, 2], tmap; xlabel = "Bad", ylabel = "Good", zlabel = "Uncertain")

f

ta.width = Relative(0.7)
f


# ## What is a ternary colormap?

# The resulting color is created by adding the colors from each colormap at the value of the variable.
# So, a color would be defined as `xmap(x) + ymap(y) + zmap(z)`, where the `*map` functions take in a
# number and return a color.

# A [`TernaryColormap`](@ref) is made of three color gradients, `xmap`, `ymap`, and `zmap`.  These are 
# Julia color gradient objects which can be created by the `cgrad` function - see its documentation for
# more details.

# Let's explore these gradients in more detail:

tmap = TernaryColormap()
fig = Figure()
with_theme(Attributes(
    Colorbar = (
        vertical = false, flipaxis = false, height = 40,
        ticks = Makie.LinearTicks(5)
    ))) do
    xcb = Colorbar(fig[1, 1], label = "x", colorrange = (0, 1), colormap = tmap.xmap)
    xlb = Label(fig[1, 0], text = "x", font = :bold, fontsize = 35, tellheight = false)
    ycb = Colorbar(fig[2, 1], label = "y", colorrange = (0, 1), colormap = tmap.ymap)
    ylb = Label(fig[2, 0], text = "y", font = :bold, fontsize = 35, tellheight = false)
    zcb = Colorbar(fig[3, 1], label = "z", colorrange = (0, 1), colormap = tmap.zmap)
    zlb = Label(fig[3, 0], text = "z", font = :bold, fontsize = 35, tellheight = false)
end
fig

# These are the individual gradients of the ternary colormap.

# ## Custom ternary colormaps

# Care must be taken when creating a ternary colormap, to ensure that 
# the colors add up, even at their maximum, to something reasonable.  

# For example,
fig = Figure()
ax, im = TernaryColorlegend(fig[1, 1], TernaryColormap(cgrad(:Oranges), cgrad(:Purples), cgrad(:Greens)))
fig

# This looks white, because the output of the sum of these colors is too high!

# We can fix this by making the colors darker:
ocg = cgrad(:Oranges)
ocg_hsl = ocg.colors.colors .|> Makie.Colors.HSL
ocg_dark = map(x -> Makie.Colors.HSL(x.h, x.s, x.l * 0.3), ocg_hsl) |> cgrad

pcg = cgrad(:Purples)
pcg_hsl = pcg.colors.colors .|> Makie.Colors.HSL
pcg_dark = map(x -> Makie.Colors.HSL(x.h, x.s, x.l * 0.3), pcg_hsl) |> cgrad

gcg = cgrad(:Greens)
gcg_hsl = gcg.colors.colors .|> Makie.Colors.HSL
gcg_dark = map(x -> Makie.Colors.HSL(x.h, x.s, x.l * 0.3), gcg_hsl) |> cgrad

# Let's see what this gave us.

fig = Figure()
ax, im = TernaryColorlegend(fig[1, 1], TernaryColormap(ocg_dark, pcg_dark, gcg_dark))
fig

# Well, it _technically_ works...but isn't that good and won't really show you anything.

# Another option is to use PerceptualColourMaps.jl, by Peter Kovesi (of `colorcet` fame).
# This is where Karmana.jl gets its own ternary colour map from.

# These are perceptually uniform colour gradients, where no one colour looks extra bright or
# dark.  
# This allows humans to more easily understand what's going on, instead of being led astray
# by false trends in luminosity (see the many scathing reviews of Matlab's rainbow colormap for more info on this).

# You can usually generate any colormap by using `PerceptuallyUniformColourmaps.equalisecolourmap` (note the British English spelling here).

TernaryColormap(
    cgrad([:cyan, :black]),
    cgrad([:magenta, :black]),
    cgrad([:yellow, :black]),
) |> image
