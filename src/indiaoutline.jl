
"""
    _set_plot_z(plot, zlevel::Real)

Sets the plot's z-level to the provided argument,
leaving the rest of the translation attributes 
the same.
"""
function _set_plot_z(plot, zlevel::Real)
    current_z = plot.transformation.translation[][3]
    translate!(Makie.Accum, plot, 0, 0, zlevel - current_z)
end

"""
    _missing_in(x, set)

Handles the case where `x` is missing, which `in` 
does not.  If x is missing and there is a missing
value in `set`, then returns true.  If there is no
missing value in `set`, returns false.  Otherwise,
the behaviour is the same as `Base.in`.
"""
function _missing_in(x, set)
    if ismissing(x) 
        return any(ismissing(set))
    else
        return in(x, skipmissing(set))
    end
end

function id_key_for_admin_level(admin_level::Symbol)
    return if admin_level == :State
        :st_cen_cd
    elseif admin_level == :HR
        :hr_nmbr
    elseif admin_level == :District
        :dt_cen_cd
    else
        @error("The admin code `$admin_code` which you passed is invalid.  Valid admin codes are `:State`, `:HR`, and `:District`.")
    end
end

_nan_color(T::Type{<: Number}, nan_color) = T(NaN)
_nan_color(::Type{<: Colors.Colorant}, nan_color) = nan_color
_nan_color(::Type{<: Any}, nan_color) = NaN

"""
    indiaoutline!(admin_level::Symbol, ids::Vector, vals::Vector{<: Real}; kw_args...)
    indiaoutline!(admin_level::Symbol, dataframe::DataFrame, [id_column::Symbol], value_column::Symbol; kw_args...)

Plots an outline of India, merged with the data passed in.  This data must fundamentally have two things:
a column of IDs, and a column of values.  The IDs must match the IDs in the CPHS database, 
and the values may be either numbers, or explicit colors.

# Arguments

`admin_level` must be one of `:State`, `:HR`, or `:District`.  

`ids` must be a `Vector{Union{Int, Missing}}` or a `Vector{Int}`.  It and `vals` must have the same length.

# Attributes


One can set the attributes of the various plot elements by setting the values of the corresponding nested Attributes. 
These are `plot.State`, `plot.HR`, `plot.District`, and `plot.River`.

For example, to set the stroke width of districts to `0.25`, one would do:

```julia
plot.District.strokewidth[] = 0.25
```

The attributes available for `State`, `HR`, and `District` are those of `poly`; the attributes available for `River` are those of `lines`.

## Cropping the map to provided data

If the attribute `crop_to_data` is `true`, then this crops the map to the bounding box of the provided IDs only, and does not draw any other states/HRs/districts.
Otherwise, all available geometries are drawn, but only the provided IDs are colored by their values; the rest of the geometries remain transparent.

## Controlling how the data is merged

You can control the column on which data is merged by setting the `merge_column` and `external_merge_column` keyword arguments.

- `merge_column` specifies the key with which to merge of the provided `ids` to the CPHS database for that admin level.
- `external_merge_column` specifies the key with which to merge the provided `ids` with the lower admin level geometries.  

For example, if the provided `admin_level` is `:State`, then `merge_key` will control the key for `state_df`, and `external_merge_key`
will control the key for `hr_df` and `district_df`.

To see all available attributes and their defaults, have a look at the extended help section by running `??indiaoutline!` in the REPL.
 
# Extended help

## Available attributes, and their values

$(Makie.ATTRIBUTES)
"""
@recipe(IndiaOutline, admin_level, ids, vals) do scene
    Attributes(
        State = (
            strokewidth = 0.20,
            strokecolor = colorant"black",
            nan_color = RGBAf(0,0,0,0),
            visible = true,
            zlevel = 101,
            names = false,
            label = "States",
        ),
        HR = (
            strokewidth = 0.20,
            strokecolor = Makie.wong_colors()[2],
            nan_color = RGBAf(0,0,0,0),
            visible = true,
            zlevel = 99,
            names = false,
            label = "HR regions",
        ), 
        District = (
            strokewidth = 0.2,
            strokecolor = colorant"gray55",
            nan_color = RGBAf(0,0,0,0),
            visible = true,
            zlevel = 98,
            names = false,
            label = "Districts",
        ),
        River = (
            linewidth = 0.2,
            color = colorant"lightblue",
            visible = true,
            zlevel = 97,
            label = "Rivers"
        ),
        Legend = (
            draw = true,
            polypoints = 1,
        ),
        colormap = Makie.inherit(scene, :colormap, :viridis),
        colorrange = Makie.automatic,
        highclip = false,
        lowclip = false,
        crop_to_data = false,
        merge_column = Makie.automatic,
        external_merge_column = Makie.automatic,
    )

end

function Makie.plot!(plot::IndiaOutline)

    # first, perform the merging
    admin_level = Makie.to_value(plot.converted[1])

    district_geoms  = Observable{Vector{GeometryBasics.MultiPolygon{2, Float64}}}()#={Vector{<: Union{GeometryBasics.Polygon{2, Float64}, GeometryBasics.MultiPolygon{2, Float64}}}}=#
    hr_geoms        = Observable{Vector{GeometryBasics.MultiPolygon{2, Float64}}}()#={Vector{<: Union{GeometryBasics.Polygon{2, Float64}, GeometryBasics.MultiPolygon{2, Float64}}}}=#
    state_geoms     = Observable{Vector{GeometryBasics.MultiPolygon{2, Float64}}}()#={Vector{<: Union{GeometryBasics.Polygon{2, Float64}, GeometryBasics.MultiPolygon{2, Float64}}}}=#
    
    district_labels = Observable{Vector{String}}()
    hr_labels       = Observable{Vector{String}}()
    state_labels    = Observable{Vector{String}}()

    district_colors = Observable{Any}()
    hr_colors       = Observable{Any}()
    state_colors    = Observable{Any}()

    value_colname = gensym()


    merge_column = plot.merge_column[] isa Makie.Automatic ? id_key_for_admin_level(admin_level) : plot.merge_column[]
    external_merge_column = plot.external_merge_column[] isa Makie.Automatic ? merge_column : plot.external_merge_column[]

    # create the merged hr, state, district polygons
    geom_color_func = if admin_level == :State

        # plot.HR.zlevel[] = plot.State.zlevel[] + 3
        # plot.District.zlevel[] = plot.State.zlevel[] + 2
        # plot.River.zlevel[] = plot.State.zlevel[] + 1
        nan_color = _nan_color((nonmissingtype(eltype(plot.converted[3][]))), plot.State.nan_color[])

        onany(plot.converted[2], plot.converted[3], plot.crop_to_data) do ids, vals, crop
            # create a dataframe with the inputs which we can use to merge
            df_to_merge = DataFrame(merge_column => ids, value_colname => vals; copycols = false)
            # do we crop India or not?
            merge_method = crop ? DataFrames.innerjoin : DataFrames.outerjoin
            
            merged_df = merge_method(Karmana.state_df[], df_to_merge; on = merge_column, matchmissing = :equal)
            state_geoms[] = merged_df.geometry
            state_colors[] = map(x -> ismissing(x) ? nan_color : x, merged_df[!, value_colname])
            merge_codes = unique(merged_df[!, external_merge_column])
            hr_geoms.val = filter(external_merge_column => Base.Fix2(_missing_in, merge_codes), Karmana.hr_df[]; view = false)[:, :geometry]
            hr_colors.val = fill(NaN, length(hr_geoms.val))
            notify(hr_geoms); notify(hr_colors)
            district_geoms.val = filter(external_merge_column => Base.Fix2(_missing_in, merge_codes), Karmana.district_df[]; view = false)[:, :geometry]
            district_colors.val = fill(NaN, length(district_geoms.val))
            notify(district_geoms); notify(district_colors)
        end
    elseif admin_level == :HR

        # plot.State.zlevel[] = plot.HR.zlevel[] + 3
        # plot.District.zlevel[] = plot.HR.zlevel[] + 2
        # plot.River.zlevel[] = plot.HR.zlevel[] + 1

        nan_color = _nan_color((nonmissingtype(eltype(plot.converted[3][]))), plot.HR.nan_color[])

        onany(plot.converted[2], plot.converted[3], plot.crop_to_data) do ids, vals, crop
            # create a dataframe with the inputs which we can use to merge
            df_to_merge = DataFrame(merge_column => ids, value_colname => vals; copycols = false)
            # do we crop India or not?
            merge_method = crop ? DataFrames.innerjoin : DataFrames.outerjoin
            # merge the dataframes using the given method
            merged_df = merge_method(Karmana.hr_df[], df_to_merge; on = merge_column, matchmissing = :equal)
            # update all other Observables(geoms, colors, etc)
            hr_geoms.val = merged_df.geometry
            hr_colors.val = map(x -> ismissing(x) ? nan_color : (x), merged_df[!, value_colname])
            notify(hr_geoms); notify(hr_colors)

            merge_codes = unique(merged_df[!, external_merge_column])
            state_codes = unique(merged_df[!, :st_nm])

            state_geoms.val = filter(:st_nm => Base.Fix2(_missing_in, state_codes), Karmana.state_df[]; view = true)[!, :geometry]
            state_colors.val = fill(NaN, length(state_geoms.val))
            notify(state_geoms); notify(state_colors)
            district_geoms.val = filter(external_merge_column => Base.Fix2(_missing_in, merge_codes), Karmana.district_df[]; view = true)[!, :geometry]
            district_colors.val = fill(NaN, length(district_geoms.val))
            notify(district_geoms); notify(district_colors)
        end
    elseif admin_level == :District

        # plot.State.zlevel[] = plot.District.zlevel[] + 3
        # plot.HR.zlevel[] = plot.District.zlevel[] + 2
        # plot.River.zlevel[] = plot.District.zlevel[] + 1

        nan_color = _nan_color((nonmissingtype(eltype(plot.converted[3][]))), plot.District.nan_color[])

        onany(plot.converted[2], plot.converted[3], plot.crop_to_data) do ids, vals, crop
            # create a dataframe with the inputs which we can use to merge
            df_to_merge = DataFrame(merge_column => ids, value_colname => vals; copycols = false)
            # do we crop India or not?
            merge_method = crop ? DataFrames.innerjoin : DataFrames.outerjoin
            
            merged_df = merge_method(Karmana.district_df[], df_to_merge; on = merge_column, matchmissing = :equal)
            district_geoms[] = merged_df.geometry
            district_colors[] = map(x -> ismissing(x) ? nan_color : (x), merged_df[!, value_colname])

            state_codes = unique(merged_df[!, :st_nm])
            hr_codes = unique(merged_df[!, :hr_nmbr])
            state_geoms.val = filter(:st_nm => Base.Fix2(_missing_in, state_codes), Karmana.state_df[]; view = true)[:, :geometry]
            state_colors.val = fill(NaN, length(state_geoms.val))
            notify(state_geoms); notify(state_colors)

            hr_geoms.val = filter(:hr_nmbr => Base.Fix2(_missing_in, hr_codes), Karmana.hr_df[]; view = true)[:, :geometry]
            hr_colors.val = fill(NaN, length(hr_geoms.val))
            notify(hr_geoms); notify(hr_colors)

        end
    else
        @error "Admin level $admin_level not known - must be one of `:State`, `:HR`, or `:District`."
    end
    notify(plot[2])

    state_plot    = poly!(plot, plot.State, state_geoms; color = state_colors, colormap = plot.colormap, highclip = get(plot, :highclip, false), lowclip = get(plot, :lowclip, false))
    hr_plot       = poly!(plot, hr_geoms; color = hr_colors, colorrange = get(plot, :colorrange, (0, 1)), colormap = plot.colormap, highclip = get(plot, :highclip, false), lowclip = get(plot, :lowclip, false), plot.HR...)
    district_plot = poly!(plot, district_geoms; color = district_colors, colormap = plot.colormap, colorrange = get(plot, :colorrange, (0, 1)), highclip = get(plot, :highclip, false), lowclip = get(plot, :lowclip, false), plot.District...)
    river_plot    = lines!(plot, GeoMakie.geo2basic(Karmana.india_rivers[]); inspectable = false, xautolimits = false, yautolimits = false, plot.River...)


    on(Base.Fix1(_set_plot_z, state_plot), plot.State.zlevel; update = true)
    on(Base.Fix1(_set_plot_z, hr_plot), plot.HR.zlevel; update = true)
    on(Base.Fix1(_set_plot_z, district_plot), plot.District.zlevel; update = true)
    on(Base.Fix1(_set_plot_z, river_plot), plot.River.zlevel; update = true)

    return plot
end

# fix an issue where rivers are still taken into account, 
# even when set to invisible, and the plot is not excluded
# even when the exclude function returns true.
# TODO: file an issue on Makie!
function Makie.data_limits(plot::IndiaOutline)
    return #=reduce(Base.union, =#Makie.data_limits.(plot.plots[1#=:3=#])#)
end

# populate the colorrange field
function Makie.calculated_attributes!(::Type{<: IndiaOutline}, plot)
    # Makie.color_and_colormap!(plot, plot[3])
end


# some argument conversions, so people can pass in DataFrames directly.

function Makie.convert_arguments(::Type{<: IndiaOutline}, admin_level::Symbol, dataframe::AbstractDataFrame, value_column::Symbol)
    id_column = id_key_for_admin_level(admin_level)
    if id_column in Tables.columnnames(dataframe)
        return (admin_level, dataframe[:, id_column], dataframe[:, value_column])
    else
        @error("""
        Your DataFrame did not have the expected admin column `$id_column`!  
        Please ensure that it has this, or pass the required column name directly 
        by invoking `indiaoutline!(ax, admin_level, dataframe, id_column, value_column)`.
        """)
    end
end

function Makie.convert_arguments(::Type{<: IndiaOutline}, admin_level::Symbol, dataframe::AbstractDataFrame, id_column::Symbol, value_column::Symbol)
    return (admin_level, dataframe[:, id_column], dataframe[:, value_column])
end

function Makie.convert_arguments(::Type{<: IndiaOutline}, admin_level::Symbol, ::Symbol)
    return (admin_level, [], [])
end

function Makie.convert_arguments(::Type{<: IndiaOutline}, ::Symbol)
    return (:State, [], [])
end
