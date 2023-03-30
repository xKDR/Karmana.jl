# Karmana

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://xKDR.github.io/Karmana.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://xKDR.github.io/Karmana.jl/dev/)
[![Build Status](https://github.com/xKDR/Karmana.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/xKDR/Karmana.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/xKDR/Karmana.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/xKDR/Karmana.jl)

Karmana.jl is a library which implements utilities to munge CMIE CPHS data and visualize it.  It exposes multiple, orthogonal capabilities.

Karmana's visualization utilities are built on the [Makie.jl](https://github.com/MakieOrg/Makie.jl) ecosystem, including the [GeoMakie.jl](https://github.com/MakieOrg/GeoMakie.jl) package.


The package is built to automate some processes to:
- Retrieve and process data from the CMIE CPHS and Capex databases
- Plot this data on maps of India.
- Create coherent and good-looking posters of plots quickly and easily.

## Installing

Karmana.jl is meant to work with CMIE CPHS data, and is not meant to be released to the General registry.

```julia
using Pkg
Pkg.add(url = "https://github.com/xKDR/Karmana.jl")
```

To add a specific branch or tag, provide the `rev = "branch_name"` keyword argument.

## Usage

Karmana.jl implements several orthogonal functions.  For more information, please see the documentation API page, or by running `?funcname` in the REPL to access Julia's help mode.

### Plotting and visualization

- `create_page(page_size::Symbol, args...; kwargs...)`: Creates a Makie.jl figure which is optimized for a figure of the appropriate size, along with a "header" row (`GridLayout`) which has a logo and poster title, and a "footer" row (`GridLayout`) which has a description `Label`, space for a legend or colorbar, and a QR code with a customizable link.  See the documentation for more!
- `indiaoutline!(admin_level::Symbol, ids, vals)`: A Makie.jl recipe which is able to plot at one of three admin levels (`:State`, `:HR`, and `:District`) - and display the other admin levels' borders.
- `TernaryColormap(xgrad, ygrad, zgrad)`, which creates a "ternary colormap" that can be called on `x, y, z` values for which `x + y + z = 1`, and returns a ternary interpolated version of the color at the specified coordinates on the plane.

#### Global variables

All of these variables are populated by `Karmana.__init__()`, and can their values can be accessed by, for example, `Karmana.state_df[]` (note the empty square brackets, which indicate that you're accessing the value of the `Ref`).

- `state_df::Ref{DataFrame}`: A `DataFrame` which holds geometry data and identification keys for India's states.
- `hr_df::Ref{DataFrame}`: A `DataFrame` which holds geometry data and identification keys for India's homogeneous regions, as defined by CMIE.
- `district_df::Ref{DataFrame}`: A `DataFrame` which holds geometry data and identification keys for India's districts.
- `india_rivers::Ref{ArchGDAL.IGeometry}`: An `ArchGDAL.IGeometry` which holds the intersection of the rivers of the world with the border of India.

### CPHS helper functions

Karmana has several CPHS helper functions to parse data.

### Capex helper functions

Karmana has some parsers for CMIE Capex data lat/long strings.

### Spatial utilities

Karmana has some geodetic/spatial utilities, like `annular_ring` and `line_to_geodetic_width_poly`.  See the docs and examples for more information!

## Environment variables

Karmana can be configured by the following environment variables:
- `KARMANA_DISTRICT_SHAPEFILE` which points to a shapefile which Karmana should use to populate the district, HR and state dataframes.  Note that there are a lot of assumptions made on the structure of the shapefile - look at the code of `Karmana.__init__()` to see what these are.
- `KARMANA_APPLY_SHAPEFILE_PATCHES` indicates whether to apply certain patches to the shapefile (`"true"`) or not (`"false"`).  Defaults to true.
- `KARMANA_RIVER_SHAPEFILE` indicates the path to some shapefile which contains a selection of rivers (usually as linestrings).  If not found, Karmana will download this data from UNESCO.
