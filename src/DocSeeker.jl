module DocSeeker

using StringDistances
using Juno, Hiccup

struct DocObj
  name::String
  mod::String
  text::String
  path::String
  line::Int
end

# TODO: better string preprocessing.
"""
    score(needle, s::Docs.DocStr) -> Float

Scores `s` against the search query `needle`. Returns a `Float` between 0 and 1.
"""
function score(needle::String, s::Docs.DocStr)
  binding = haskey(s.data, :binding) ? string(s.data[:binding].var) : ""
  length(s.text) == 0 && return compare(Hamming(), needle, binding)
  doc = lowercase(Docs.stripmd(Markdown.parse(join(s.text, ' '))))
  max(compare(Jaro(), needle, binding), 0.8*compare(TokenSet(Jaro()), lowercase(needle), doc))
end

function score(needle::String, s::DocObj)
  binding = string(s.name)
  length(s.text) == 0 && return compare(Hamming(), needle, binding)
  doc = lowercase(Docs.stripmd(get(s.md, Markdown.parse(s.text))))
  max(compare(Jaro(), needle, binding), 0.8*compare(TokenSet(Jaro()), lowercase(needle), doc))
end

# rendering methods
function Juno.render(i::Juno.Inline, d::Docs.DocStr)
  Juno.render(i, Juno.Tree(d.data[:binding], [Markdown.parse(join(d.text, ' '))]))
end

function Juno.render(i::Juno.Inline, d::DocObj)
  Juno.render(i, Juno.Tree(span(span(".syntax--support.syntax--function", d.name), span(" @ $(d.path):$(d.line)")), [Markdown.parse(d.text)]))
end

include("introspective.jl")
include("finddocs.jl")
include("static.jl")
include("db.jl")

end # module
