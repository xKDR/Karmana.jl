"""
    get_HR_number(hr::Union{String, Missing})::Union{Int, Missing}

Extracts the number from a string of a form `"HR ???"` and returns it.
If the input is `missing`, then `missing` is returned.
"""
function get_HR_number(hr::String)
    return parse(Int, hr[(findfirst(' ', hr)+1):end])
end

get_HR_number(::Missing) = missing

"""
    get_sentiment_props(df, sentiment_key; good = "Good times", bad = "Bad times", uncertain = "Uncertain times")
    
Takes in a DataFrame from the CPHS aspirational wave database, and returns a tuple of `(bad_prop, good_prop, uncertain_prop)`.

The keys can be changed by keyword arguments; fundamentally, this is a helper function to extract proportions from a three-value system.
"""
function get_sentiment_props(df, sentiment_key; good = "Good times", bad = "Bad times", uncertain = "Uncertain times")
    total_pop = sum(df.total)
    good_ind = findfirst(==(good), df[!, sentiment_key])
    bad_ind = findfirst(==(bad), df[!, sentiment_key])
    uncertain_ind = findfirst(==(uncertain), df[!, sentiment_key])
    good_prop = isnothing(good_ind) ? 0.0 : df[good_ind, :total] / total_pop
    bad_prop = isnothing(bad_ind) ? 0.0 : df[bad_ind, :total] / total_pop
    uncertain_prop = isnothing(uncertain_ind) ? 0.0 : df[uncertain_ind, :total] / total_pop
    return ((bad_prop, good_prop, uncertain_prop))
end

