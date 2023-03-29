# A couple of questions about this choropleth.
# 1: how can you pass multiple attr values?  Maybe make it per level, using broadcast_foreach, and just wrap e.g. `linestyle` and `colormap` if they are not vecvecs?
# 2: how does updating work?  Where do you pass the shapefiles?  Rather they be kwargs and not args.
function multilevelchoropleth!(plot, datas, admin_level, ids, vals; merge_column, external_merge_column)

    poly_observables = [Observable{Any}() for i in eachindex(datas)]
    color_observables = [Observable{Any}() for i in eachindex(datas)]
    for i in 1:(admin_level-1)
        poly_obs = Observable{Any}()
        color_obs = Observable{Any}()
        push!(poly_observables, poly_obs)
        push!(color_observables, color_obs)
    end

    poly!(plot, datas[admin_level, ...])

    for i in (admin_level+1)+1:length(datas)
        poly_obs = Observable{Any}()
        color_obs = Observable{Any}()
        push!(poly_observables, poly_obs)
        push!(color_observables, color_obs)
    end



end