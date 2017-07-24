__precompile__()

module DocSeeker

using StringDistances
using Juno, Hiccup

# TODO: figure out how to get something useable out of `DocObj.sig`
# TODO: figure out how to save `sig` and not kill serialization
struct DocObj
  name::String
  mod::String
  typ::String
  # sig::Any
  text::String
  html::String
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
  # TODO: figure out why this sometimes throws a `MethodError: no method matching stripmd(::Symbol)`
  # doc = lowercase(Docs.stripmd(Markdown.parse(s.text)))
  doc = lowercase(s.text)

  binding_score = compare(Winkler(Jaro()), needle, binding)
  docs_score    = compare(TokenSet(Jaro()), lowercase(needle), doc)

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

include("fuzzaldrin.jl")
include("introspective.jl")
include("finddocs.jl")
include("static.jl")
# include("db.jl")
include("precompile.jl")
include("documenter.jl")

_precompile_()

end # module
