# CMIE CapEx utilities

## Data munging

Apply these functions to columns from the CapEx database.

```@docs
latlong_string_to_points
points_weights
```

## Geographic utilities

We also have geographic utilities, which use e.g. Rasters.  

!!! note
    Maybe this section should be its own page, since the functionality is pretty orthogonal?

### Annular rings

```@docs
annular_ring
```

### Geodetically widened lines

```@docs
line_to_geodetic_width_poly
```
