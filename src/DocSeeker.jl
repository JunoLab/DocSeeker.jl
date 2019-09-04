__precompile__()

module DocSeeker

export searchdocs

using StringDistances, Hiccup, Requires
using REPL: stripmd
import Markdown

# TODO: figure out how to get something useable out of `DocObj.sig`
# TODO: figure out how to save `sig` and not kill serialization
struct DocObj
  name::String
  mod::String
  typ::String
  # sig::Any
  text::String
  html::Markdown.MD
  path::String
  line::Int
  exported::Bool
end

function Base.hash(s::DocObj, h::UInt)
  hash(s.name, hash(s.mod, hash(s.typ, hash(s.text, hash(s.exported, hash(s.line,
       hash(s.path, hash(:DocObj, h))))))))
end
function Base.:(==)(a::DocObj, b::DocObj)
  isequal(a.name, b.name) && isequal(a.mod, b.mod) && isequal(a.typ, b.typ) &&
  isequal(a.text, b.text) && isequal(a.path, b.path) && isequal(a.line, b.line) &&
  isequal(a.exported, b.exported)
end

# TODO: better string preprocessing.
"""
    score(needle, s::Docs.DocObj) -> Float

Scores `s` against the search query `needle`. Returns a `Float` between 0 and 1.
"""
function score(needle::String, s::DocObj, name_only = false)
  score = 0.0
  length(needle) == 0 && return score

  needles = split(needle, ' ')
  binding_score = length(needles) > 1 ? 0.0 : compare(needle, s.name, Winkler(Jaro()))
  c_binding_score = length(needles) > 1 ? 0.0 : compare(lowercase(needle), lowercase(s.name), Winkler(Jaro()))

  if name_only
    score = c_binding_score
  else
    docs_score = compare(lowercase(needle), lowercase(s.text), TokenSet(Jaro()))

    # bonus for exact case-insensitive binding match
    binding_weight = c_binding_score == 1.0 ? 0.95 : 0.7

    score += binding_weight*c_binding_score + (1 - binding_weight)*docs_score
  end

  # penalty if cases don't match
  binding_score < c_binding_score && (score *= 0.98)
  # penalty if binding has no docs
  length(s.text) == 0 && (score *= 0.85)
  # penalty if binding isn't exported
  s.exported || (score *= 0.99)

  return score
end

# console rendering
function Base.show(io::IO, d::DocObj)
  println(io, string(d.mod, '.', d.name, " @$(d.path):$(d.line)"))
end

function Base.show(io::IO, ::MIME"text/plain", d::DocObj)
  println(io, string(d.mod, '.', d.name, " @$(d.path):$(d.line)"))
  println(io)
  println(io, d.text)
end

include("introspective.jl")
include("finddocs.jl")
include("static.jl")
include("documenter.jl")

function __init()__
  # improved rendering if used in Atom:
  @require Atom="c52e3926-4ff0-5f6e-af25-54175e0327b1" begin
    function Atom.render(i::Atom.Inline, d::DocObj)
      Atom.render(i, Atom.Tree(span(span(".syntax--support.syntax--function", d.name),
                                    span(" @ $(d.path):$(d.line)")), [Atom.render(i, Atom.renderMD(d.html))]))
    end
  end
end

end # module
