# Basic converts for e.g. Rasters
# TODO: remove after the Rasters PR is merged.
function Makie.convert_arguments(::Makie.ContinuousSurface, raw_raster::AbstractRaster{<: Real, 2})
    ds = Rasters.DimensionalData._fwdorderdims(raw_raster)
    A = permutedims(raw_raster, ds)
    x, y = dims(A)
    xs, ys, zs = Rasters.DimensionalData._withaxes(x, y, (A))
    return (xs, ys, collect(zs))
end

function Makie.convert_arguments(::Makie.DiscreteSurface, raw_raster::AbstractRaster{<: Real, 2})
    ds = Rasters.DimensionalData._fwdorderdims(raw_raster)
    A = permutedims(raw_raster, ds)
    x, y = dims(A)
    xs, ys, zs = Rasters.DimensionalData._withaxes(x, y, (A))
    return (xs, ys, collect(zs))
end

# A way to compose Makie figures together
# TODO: upstream this
"""
    get_all_blocks(layout::GridLayout)

Recursively gets all blocks in that layout, and returns a flattened Vector of blocks.
"""
function get_all_blocks(layout::GridLayout, blocks = Makie.Block[])
    contents = Makie.contents(layout)
    append!(blocks, filter(c -> c isa Makie.Block, contents))
    for sublayout in filter(c -> c isa Makie.GridLayout, contents)
        get_all_blocks(sublayout, blocks)
    end
    return blocks
end

"""
    move!(position::GridPosition, layout::GridLayout)

Moves `layout` and all its contents to `position`.
This works even with different figures, i.e., different layout roots.

Note that this function assumes that both `position` and `layout`
are associated with some `Figure` - even if those `Figure`s are different.

## Example

```julia
fig1 = Figure(resolution = (1500, 1500))
fig2 = Figure()

gl1 = GridLayout(fig1[1, 1])
gl2 = GridLayout(fig1[1, 2])

for gl in (gl1, gl2)
    lines(gl[1, 1], rand(10))
    scatter(gl[1, 2], rand(10))
    heatmap(gl[2, 1], rand(100, 100))
    surface(gl[2, 2], Makie.peaks())
end

move!(fig2[1, 1], gl1)
fig2
```

## TODOS
- Get screen events (mouse, keyboard) hooked up
"""
function move!(position::Makie.GridPosition, layout::GridLayout; remove_scenes_from_old_figure = true)
    # first, get figures
    new_figure = Makie.get_figure(position)
    old_figure = Makie.GridLayoutBase.top_parent(layout)
    @assert old_figure isa Figure
    @assert new_figure isa Figure

    # move the layout to the new figure
    position[] = layout
    # tell the layout that it's been moved
    layout.parent = position.layout

    # move the Blocks' blockscenes to the new figure
    for block in get_all_blocks(layout)
        # push the blockscene of each block to the new figure
        push!(new_figure.scene.children, block.blockscene)
        block.blockscene.parent = new_figure.scene
        # optionally, remove the scenes from the old figure
        if remove_scenes_from_old_figure
            deleteat!(old_figure.scene.children, findfirst(x -> x === block.blockscene, old_figure.scene.children))
        end
        # TODO: this doesn't work, we probably need to set up mouse and keyboard handlers again
        # for the new Scene.
        nodes = map(fieldnames(Makie.Events)) do field
            if !(field ∈ (:window_area, :mousebuttonstate, :keyboardstate))
                Makie.connect!(getfield(new_figure.scene.events, field), getfield(block.blockscene.events, field))
            end
        end
    end

    return position
end

move!(position::Makie.GridPosition, figure::Figure; remove_scenes_from_old_figure = true) = move!(position, figure.layout; remove_scenes_from_old_figure)
