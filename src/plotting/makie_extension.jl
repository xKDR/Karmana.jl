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

        # old_screens = block.blockscene.current_screens
        # new_screens = new_figure.scene.current_screens
        # foreach_scene(block.blockscene) do scene
        #     Makie.disconnect_screen.((scene,), old_screens)
        #     # for screen in new_screens
        #     #     try
        #     #         Makie.connect_screen(scene, screen)
        #     #     catch
        #     #     end
        #     # end
        # end

        # push the blockscene of each block to the new figure
        push!(new_figure.scene.children, block.blockscene)
        block.blockscene.parent = new_figure.scene
        Makie.push_screen!.((block.blockscene,), new_figure.scene.current_screens)
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

function foreach_scene(f, scene::Scene)
    f(scene)
    foreach_scene.((f,), scene.children)
end

function connect_scene_rec(scene, old_screen, new_screen; fields...)
    for (field, value) in fields
        setfield!(scene, field, value)
    end
    for child_scene in scene.children
        set_scene_fields!(child_scene; fields...)
    end
end

move!(position::Makie.GridPosition, figure::Figure; remove_scenes_from_old_figure = true) = move!(position, figure.layout; remove_scenes_from_old_figure)

# fig1 = Figure(resolution = (1500, 1500));
# fig2 = Figure();

# gl1 = GridLayout(fig1[1, 1])
# gl2 = GridLayout(fig1[1, 2])

# for gl in (gl1, gl2)
#     lines(gl[1, 1], rand(10))
#     scatter(gl[1, 2], rand(10))
#     heatmap(gl[2, 1], rand(100, 100))
#     surface(gl[2, 2], Makie.peaks())
# end

# display(GLMakie.Screen(title = "fig1"), fig1)
# display(GLMakie.Screen(title = "fig2"), fig2)
# move!(fig2[1, 1], gl1)
# display(GLMakie.Screen(title = "fig2 after move"), fig2)

# using GLMakie




# fig1

# fig2