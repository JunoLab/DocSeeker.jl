module DocSeeker

using StringDistances
using Juno

include("introspective.jl")
include("finddocslink.jl")
include("static.jl")
include("db.jl")

# TODO: better string preprocessing.
"""
    score(needle, s::Docs.DocStr) -> Float

Scores `s` against the search query `needle`. Returns a `Float` between 0 and 1.
"""
function score(needle::String, s::Docs.DocStr)
  binding = haskey(s.data, :binding) ? string(s.data[:binding].var) : ""
  length(s.text) == 0 && return compare(Hamming(), needle, binding)
  doc = lowercase(join(s.text, ' '))
  max(1.1*compare(Jaro(), needle, binding), 0.9*compare(TokenSet(Jaro()), lowercase(needle), doc))
end

# rendering methods
function Juno.render(i::Juno.Inline, d::Docs.DocStr)
  Juno.render(i, Juno.Tree(d.data[:binding], [Markdown.parse(join(d.text, ' '))]))
end

end # module
