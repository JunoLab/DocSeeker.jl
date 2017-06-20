__precompile__()

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
  doc = lowercase(Docs.stripmd(get(s.object, Markdown.parse(join(s.text, ' ')))))
  max(compare(Jaro(), needle, binding), 0.8*compare(TokenSet(Jaro()), lowercase(needle), doc))


# https://github.com/atom/fuzzaldrin/blob/master/src/scorer.coffee
function fuzzaldrin_score(needle::String, haystack::String)
  needle == haystack && return 1.0

  totalCharacterScore = 0.0
  needle_length = length(needle)
  haystack_length = length(haystack)

  for (i, c) in enumerate(needle)
    lowerCaseIndex = searchindex(haystack, lowercase(c))
    upperCaseIndex = searchindex(haystack, uppercase(c))
    minIndex = min(lowerCaseIndex, upperCaseIndex)
    minIndex == 0 && (minIndex = max(lowerCaseIndex, upperCaseIndex))

    indexInString = minIndex

    indexInString == 0 && return 0.0

    characterScore = 0.1

    haystack[chr2ind(haystack, minIndex)] == c && (characterScore += 0.1)

    if indexInString == 1
      characterScore += 0.8
    elseif haystack[prevind(haystack, chr2ind(haystack, minIndex))] in ['_', '-', ' ']
      characterScore += 0.7
    end

    haystack = haystack[nextind(haystack, chr2ind(haystack, indexInString)):end]

    totalCharacterScore += characterScore
  end

  queryScore = totalCharacterScore/haystack_length
  return (queryScore*(needle_length/haystack_length) + queryScore)/2
end

function score(needle::String, s::DocObj)
  binding = s.name
  length(s.text) == 0 && return compare(Hamming(), needle, binding)
  doc = lowercase(Docs.stripmd(Markdown.parse(s.text)))
  # max(compare(Jaro(), needle, binding), 0.8*compare(TokenSet(Jaro()), lowercase(needle), doc))
  0.6*fuzzaldrin_score(needle, binding) + 0.4*compare(TokenSet(Jaro()), lowercase(needle), doc)
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
