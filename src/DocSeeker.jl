__precompile__()

module DocSeeker

using StringDistances, AutoHashEquals
using Juno, Hiccup

# TODO: figure out how to get something useable out of `DocObj.sig`
# TODO: figure out how to save `sig` and not kill serialization
@auto_hash_equals struct DocObj
  name::String
  mod::String
  typ::String
  # sig::Any
  text::String
  html::Hiccup.Node
  path::String
  line::Int
  exported::Bool
end

# TODO: better string preprocessing.
"""
    score(needle, s::Docs.DocObj) -> Float

Scores `s` against the search query `needle`. Returns a `Float` between 0 and 1.
"""
function score(needle::String, s::DocObj)
  score = 0.0
  length(needle) == 0 && return score

  binding = s.name

  binding_score = compare(Winkler(Jaro()), needle, binding)
  docs_score    = compare(TokenSort(Jaro()), lowercase(needle), lowercase(s.text))

  # bonus for exact binding match
  binding_weight = binding_score == 1.0 ? 0.8 : 0.75

  score += binding_weight*binding_score + (1 - binding_weight)*docs_score

  # penalty if binding has no docs
  length(s.text) == 0 && (score *= 0.98)
  # penalty if binding isn't exported
  s.exported || (score *= 0.99)

  return score
end

# rendering method
function Juno.render(i::Juno.Inline, d::DocObj)
  Juno.render(i, Juno.Tree(span(span(".syntax--support.syntax--function", d.name),
                                span(" @ $(d.path):$(d.line)")), [Markdown.parse(d.text)]))
end

# this is iffy.
Base.show(io::IO, m::MIME"text/html", x::Markdown.LaTeX) = print(io, "<span class=\"latex\">$(x.formula)</span>")

include("fuzzaldrin.jl")
include("introspective.jl")
include("finddocs.jl")
include("static.jl")
# include("db.jl")
include("precompile.jl")
include("documenter.jl")
include("render.jl")

_precompile_()

end # module
