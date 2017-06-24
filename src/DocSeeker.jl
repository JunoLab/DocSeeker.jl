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
  path::String
  line::Int
  exported::Bool
end

# TODO: better string preprocessing.
"""
    score(needle, s::Docs.DocStr) -> Float

Scores `s` against the search query `needle`. Returns a `Float` between 0 and 1.
"""
function score(needle::String, s::Docs.DocStr)
  binding = haskey(s.data, :binding) ? string(s.data[:binding].var) : ""
  length(s.text) == 0 && return compare(Hamming(), needle, binding)
  doc = lowercase(Docs.stripmd(get(s.object, Markdown.parse(join(s.text, ' ')))))
  max(compare(Jaro(), needle, binding), 0.8*compare(TokenSet(Jaro()), lowercase(needle), doc))
end

function score(needle::String, s::DocObj)
  score = 0.0
  length(needle) == 0 && return score

  binding = s.name
  # TODO: figure out whyt this sometimes throws a `MethodError: no method matching stripmd(::Symbol)`
  # doc = lowercase(Docs.stripmd(Markdown.parse(s.text)))
  doc = lowercase(s.text)

  # penalty if binding has no docs
  score += (length(s.text) == 0 ? 0.74 : 0.75)*compare(Jaro(), needle, binding)
  score += 0.25*compare(TokenSet(Jaro()), lowercase(needle), doc)

  # penalty if binding isn't exported
  score *= s.exported ? 1.0 : 0.99

  return score
end

# rendering methods
function Juno.render(i::Juno.Inline, d::Docs.DocStr)
  Juno.render(i, Juno.Tree(d.data[:binding], [Markdown.parse(join(d.text, ' '))]))
end

function Juno.render(i::Juno.Inline, d::DocObj)
  Juno.render(i, Juno.Tree(span(span(".syntax--support.syntax--function", d.name), span(" @ $(d.path):$(d.line)")), [Markdown.parse(d.text)]))
end

include("fuzzaldrin.jl")
include("introspective.jl")
include("finddocs.jl")
include("static.jl")
include("db.jl")
include("precompile.jl")

_precompile_()

end # module
