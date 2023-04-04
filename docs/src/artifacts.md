# Artifacts

Karmana currently uses one artifact, the India shapefile found in https://github.com/xKDR/india-maps.

To update this, you can make a new release of `india-maps`, update `Karmana.__init__` with the file path, and use `ArtifactUtils.jl`'s `add_artifact!` function to add it to the repo, under the name `india_shapefile`.  

Other artifacts should be handled similarly (i.e, a gitrepo from which we download release tarballs).

## Updating the `india_shapefile` artifact

_As easy as 1, 2, 3!_

1. Remove the `india_shapefile` entry from Karmana.jl's `Artifacts.toml` (literally, delete that text.)
2. Run `add_artifact!(joinpath("$(dirname(pathof(Karmana)))", "Artifacts.toml"), "india_shapefile", "https://github.com/xKDR/india-maps/archive/refs/tags/v0.2.0.tar.gz")` but replace the URL with the new URL for the release tarball.
3. Push your changes to the Karmana.jl repo!
