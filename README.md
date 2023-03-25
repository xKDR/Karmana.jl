# Karmana

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://xKDR.github.io/Karmana.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://xKDR.github.io/Karmana.jl/dev/)
[![Build Status](https://github.com/xKDR/Karmana.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/xKDR/Karmana.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/xKDR/Karmana.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/xKDR/Karmana.jl)

Karmana.jl is a library which implements utilities to munge CMIE CPHS data and visualize it.  It exposes multiple, orthogonal capabilities.

Karmana is built on the [Makie.jl](https://github.com/MakieOrg/Makie.jl) ecosystem, including the [GeoMakie.jl](https://github.com/MakieOrg/GeoMakie.jl) package.


The package is built to automate some processes to:
- Plot data on maps of India.
- Create coherent and good-looking posters of plots quickly and easily.


## Installing

Karmana.jl is meant to work with CMIE CPHS data, and is not meant to be released to the General registry.

```julia
using Pkg
Pkg.add(url = "https://github.com/xKDR/Karmana.jl")
```

To add a specific branch or tag, provide the `rev = "branch_name"` keyword argument.

Some functionality requires access to the xKDR maps database.  This can take one of two forms:
- Database credentials encoded in the environment variables `"MAPS_USER"` and `"MAPS_PASSWORD"`.
- A shapefile whose location is indicated by the environment variable `"KARMANA_DISTRICT_SHAPEFILE"`.\
You can either set these before loading Karmana.jl, or call `Karmana.__init__()` after setting it to reset the `state_df`, `hr_df`, and `district_df` global variables (described below).

## Usage

Karmana.jl implements several orthogonal functions.  For more information, please see the documentation API page, or by running `?funcname` in the REPL to access Julia's help mode.

- `create_page(page_size::Symbol, args...; kwargs...)`: Creates a Makie.jl figure which is optimized for a figure of the appropriate size, along with a "header" row (`GridLayout`) which has a logo and poster title, and a "footer" row (`GridLayout`) which has a description `Label`, space for a legend or colorbar, and a QR code with a customizable link.  See the documentation for more!
- `indiaoutline!(admin_level::Symbol, ids, vals)`: A Makie.jl recipe which is able to plot at one of three admin levels (`:State`, `:HR`, and `:District`) - and display the other admin levels' borders.
- `TernaryColormap(xgrad, ygrad, zgrad)`, which creates a "ternary colormap" that can be called on `x, y, z` values for which `x + y + z = 1`, and returns a ternary interpolated version of the color at the specified coordinates on the plane.

### Global variables

All of these variables are populated by `Karmana.__init__()`, and can their values can be accessed by, for example, `Karmana.state_df[]` (note the empty square brackets, which indicate that you're accessing the value of the `Ref`).

- `state_df::Ref{DataFrame}`: A `DataFrame` which holds geometry data and identification keys for India's states.
- `hr_df::Ref{DataFrame}`: A `DataFrame` which holds geometry data and identification keys for India's homogeneous regions, as defined by CMIE.
- `district_df::Ref{DataFrame}`: A `DataFrame` which holds geometry data and identification keys for India's districts.
- `india_rivers::Ref{ArchGDAL.IGeometry}`: An `ArchGDAL.IGeometry` which holds the intersection of the rivers of the world with the border of India.
