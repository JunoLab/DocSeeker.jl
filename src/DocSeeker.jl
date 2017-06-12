module DocSeeker

using StringDistances
using Juno

include("introspective.jl")
include("finddocslink.jl")
include("static.jl")

# TODO: better string preprocessing.
"""
    score(needle, s::Docs.DocStr) -> Float

Scores `s` against the search query needle. Returns a `Float` between 0 and 1.
"""
function score(needle::String, s::Docs.DocStr)
  length(s.text) == 0 && return 0.0
  binding = split(string(get(s.data, :binding, "")), '.')[end]
  doc = lowercase(join(s.text, ' '))
  (2*compare(Hamming(), needle, binding) + compare(TokenMax(Hamming()), lowercase(needle), doc))/3
end

# rendering methods
function Juno.render(i::Juno.Inline, d::Docs.DocStr)
  Juno.render(i, Juno.Tree(d.data[:binding], [Markdown.parse(join(d.text, ' '))]))
end

end # module
