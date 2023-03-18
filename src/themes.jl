
# from xkdr.org css
const xkdr_gray = colorant"#F2F1F0"
const xkdr_coral = colorant"#F57D6A"

const xkdr_regular_font = "Montserrat Sans Serif"
const xkdr_secondary_font = "Merriweather Serif"
const xkdr_footer_font = "Josefin Sans"


# style theme
function theme_xkdr()
    return merge(
        Attributes(
            # fonts = (
            #     regular = "Montserrat Sans Serif",
            #     bold = "Montserrat Sans Bold",
            #     italic = "Montserrat Sans Italic",
            #     bold_italic = "Montserrat Sans Bold Italic",
            #     secondary = "Merriweather Serif",
            #     footer = "Josefin Sans"
            # )
            Axis = (
                titlefont = :regular,
            ),
            Colorbar = (
                vertical = false,
                flipaxis = false,
                tellwidth = true,
                tellheight = false,
                alignmode = Outside(), # make sure that protrusions stay inside!
            ),
            Supertitle = (
                text = "Title", 
                font = :bold
            ),
            DescriptionLabel = (
                text = "Placeholder: This is a label which should describe your plot[s].",
                font = :regular,
                justification = :left,
                word_wrap = true,
                tellheight = true,
            ),
            
        ),
        Makie.minimal_default
    )
end

function theme_a4()
    return Attributes(
        Page = (
            logo_height = 30,
            logo_padding = 0,
            qr_code_height = 60,
            qr_code_padding = 0,
        ),
        Supertitle = (
            fontsize = 25,
            font = :bold,
        ),
        DescriptionLabel = (
            fontsize = 12,
        ),
        Axis = (
            titlesize = 16,
        ),
        fontsize = 12,
    )
end

function theme_a3()
    return Attributes(
        Page = (
            logo_height = 40,
            logo_padding = 0,
            qr_code_height = 60,
            qr_code_padding = 0,
        ),
        Supertitle = (
            fontsize = 40,
        ),
        DescriptionLabel = (;
        ),
        Axis = (
            titlesize = 20,
        ),
        Colorbar = (
            # ticklabelsize = 0f0,
            # labelsize = 0f0,
        ),
        fontsize = 16,
    )
end

function theme_a2()
    return Attributes(
        Page = (
            logo_height = 60,
            logo_padding = 0,
            qr_code_height = 72,
            qr_code_padding = 0,
        ),
        Supertitle = (
            fontsize = 50,
        ),
        DescriptionLabel = (
            fontsize = 20,
        ),
        Axis = (
            titlesize = 30,
        ),
        fontsize = 16,
    )
end

function theme_a1()
    return Attributes(
        Page = (
            logo_height = 60,
            logo_padding = 0,
            qr_code_height = 72,
            qr_code_padding = 0,
        ),
        Supertitle = (
            fontsize = 80,
        ),
        DescriptionLabel = (
            fontsize = 40,
        ),
        Axis = (
            titlesize = 55,
        ),
        fontsize = 30,
    )
end

function theme_a0()
    return Attributes(
        Page = (
            logo_height = 130,
            logo_padding = 0,
            qr_code_height = 100,
            qr_code_padding = 0,
        ),
        Supertitle = (
            fontsize = 120,
        ),
        DescriptionLabel = (
            fontsize = 70,
        ),
        Axis = (
            titlesize = 90,
        ),
        fontsize = 30,
    )
end

"""
    nearest_paper_size(width::Real, height::Real)::Symbol

Returns the closest paper size to the provided size, which must be a 2-tuple.
"""
function nearest_paper_size(width::Real, height::Real)::Symbol

end

function paper_size_theme(paper_size::Symbol) 
    if paper_size === :a4
        theme_a4()
    elseif paper_size === :a3
        theme_a3()
    elseif paper_size === :a2
        theme_a2()
    elseif paper_size == :a1
        theme_a1()
    elseif paper_size == :a0
        theme_a0()
    else
        @warn("Paper size `$paper_size` is not known!  Defaulting to `:a4`.")
        theme_a4()
    end
end


function _best_padding(paper_size::Symbol)
    if paper_size === :a4
        5
    elseif paper_size === :a3
        72
    elseif paper_size in (:a2, :a1, :a0)
        80
    else
        @warn("Paper size `$paper_size` is not known!  Defaulting to `:a4`.")
        5
    end
end
