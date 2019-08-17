# DocSeeker

[![Build Status](https://travis-ci.org/pfitzseb/DocSeeker.jl.svg?branch=master)](https://travis-ci.org/pfitzseb/DocSeeker.jl)

DocSeeker.jl provides utilities for handling documentation in local (so far) packages.

### Usage

The main entry point is `searchdocs`:
```julia
searchdocs("sin")
```
will return a vector of tuples of scores and their corresponding match. Scores are numbers
between 0 and 1, and represent the quality of a given match. Matches are `DocObj`, which
accumulate lots of metadata about a binding (e.g. name, type, location etc.).

`searchdocs` takes three keyword arguments:
- `mod::String = "Main"` will restrict the search to the given module -- by default every loaded package will be searched.
- `loaded::Bool = true` will search only packages in the current session, while `loaded = false` will search in *all* locally installed packages (actually only those in `Pkg.installed()`). Requires a call to `DocSeeker.createdocsdb()` beforehand.
- `exportedonly::Bool = false` will search all names a module has, while `exportedonly=true`
only takes exported names into consideration.

Re-generation of the cache that powers the search in all installed packages can be triggered
via `DocSeeker.createdocsdb()` (async, so no worries about killing you julia session). For now,
there is *no* automatic re-generation, though that'll be implemented soon.
