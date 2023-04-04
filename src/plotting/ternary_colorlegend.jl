
function TernaryColorlegend(gridposition, tmap::TernaryColormap = TernaryColormap(); kwargs...)

    ax = Axis(gridposition; aspect = AxisAspect(96/71))
    hidedecorations!(ax); hidespines!(ax)
    im = image!(ax, tmap)
    translate!(im, 0, 0, -1) # get image behind axis
    ta = ternaryaxis!(ax; kwargs...);

    return Makie.AxisPlot(ax, im)
end

function TernaryColorlegend(fig::Figure, bbox::Rect2f, tmap::TernaryColormap = TernaryColormap(); nsteps = 1000)

    ax = Axis(fig; bbox = bbox, aspect = AxisAspect(96/71))
    hidedecorations!(ax); hidespines!(ax)
    im = image!(ax, tmap)
    translate!(im, 0, 0, -1) # get image behind axis
    ta = ternaryaxis!(ax; kwargs...);

    return Makie.AxisPlot(ax, im)

end

# function _ternary_colorlegend!(ax; nsteps = 1000)
#     xs = LinRange(0, 1, nsteps)
#     ys = LinRange(0, 1, nsteps)
    
#     barycentric_points = TernaryDiagrams.from_cart_to_bary.(xs, ys')
    
#     colors = map(barycentric_points) do barycentric_point
#         if any(barycentric_point .< 0.0)
#             return RGBAf(1,1,1,0)
#         else
#             return suitable_rgb(barycentric_point)
#         end
#     end
    
#     # required aspect ratio: 568.0/768.0

#     tick_fontsize = 12
#     label_fontsize = 18
    
#     tax = TernaryDiagrams.ternaryaxis!(
#         ax;
#         labelx = "Bad",
#         labely = "Good",
#         labelz = "Uncertain",
#         xtickformat = tick -> "  " * string(round(Int, tick*100))*"%",
#         ytickformat = tick -> "  " * string(round(Int, tick*100))*"%",
#         ztickformat = tick -> Makie.rich(string(round(Int, tick*100))*"% ㅤ"),
#         tick_fontsize = tick_fontsize,
#         label_edge_vertical_arrow_adjustment = 0.09 * tick_fontsize/4,
#         label_edge_vertical_adjustment = 0.12 * tick_fontsize/4,
#         arrow_label_fontsize = label_fontsize * .6,
#         label_fontsize = label_fontsize,
#         label_vertex_vertical_adjustment = 0.03 * tick_fontsize/1.5,    
#         grid_line_width = 0.25,
#     );

    
#     img_plt = image!(ax, xs, ys, colors)
    
#     translate!(img_plt, 0, 0, -100)
# end
