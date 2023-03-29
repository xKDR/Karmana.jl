@recipe(QRCodePlot) do scene
    Attributes(
        on_color = Makie.inherit(scene, :color, :black),
        off_color = :transparent,
        eclevel = QRCode.Medium(),
        compact = true,
    )
end

function Makie.plot!(p::Combined{qrcode, <: Tuple{<: Makie.IntervalSets.ClosedInterval, <: Makie.IntervalSets.ClosedInterval, <: AbstractString}})
    code_matrix = lift(p[3], p.eclevel, p.compact) do link, eclevel, compact
        QRCode.qrcode(link, eclevel, compact)
    end

    image!(p, p[1], p[2], code_matrix; colorrange = (false, true), colormap = @lift([to_color($(p.off_color)), to_color($(p.on_color))]))
    
end

function Makie.convert_arguments(::Type{<: QRCodePlot}, link::AbstractString)
    return (0..1, 0..1, link)
end