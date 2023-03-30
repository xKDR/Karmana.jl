# Artifacts

Karmana currently uses one artifact, the India shapefile found in https://github.com/xKDR/india-maps.

To update this, you can make a new release of `india-maps`, update `Karmana.__init__` with the file path, and use `ArtifactUtils.jl`'s `add_artifact!` function to add it to the repo, under the name `india_shapefile`.  

Other artifacts should be handled similarly (i.e, a gitrepo from which we download release tarballs).
