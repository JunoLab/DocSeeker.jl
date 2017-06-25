# DocSeeker

[![Build Status](https://travis-ci.org/pfitzseb/DocSeeker.jl.svg?branch=master)](https://travis-ci.org/pfitzseb/DocSeeker.jl)

DocSeeker.jl provides utilities for handling documentation in local (so far) packages.

For now, `Pkg.checkout("StringDistances")` is heavily recommended, because there's a annoying
`@show` in the latest release.

### Usage

The main entry point is `search`:
```julia
search("sin")
```
will return a tuple of vectors of scores and their corresponding match. Scores are numbers
between 0 and 1, and represent the quality of a given match. Matches are `DocObj`, which
accumulate lots of metadata about a binding (e.g. name, type, location etc.).

`search` takes two keyword arguments:
- `mod::Module = Main` will restrict the search to the given module -- by default every loaded
package will be searched.
- `loaded::Bool = true` will search only packages in the current session, while `loaded = true`
will search in *all* locally installed packages (actually only those in `Pkg.dir()`).

Re-generation of the cache that powers the search in all installed packages can be triggered
via `DocSeeker.createdocsdb()`. For now, there is *no* automatic re-generation, though that'll
be implemented soon.
