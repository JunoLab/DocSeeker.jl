__precompile__()

module DocSeeker

export searchdocs

using StringDistances, Hiccup, Requires

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
  name_only ? score_name(needle, s) : score_all(needle, s)
end

function score_all(needle::String, s::DocObj)
  score = 0.0
  length(needle) == 0 && return score

  needles = split(needle, ' ')
  binding_score = length(needles) > 1 ? 0.0 : compare(Winkler(Jaro()), needle, s.name)
  docs_score    = compare(TokenSet(Jaro()), lowercase(needle), lowercase(s.text))

  # bonus for exact binding match
  binding_weight = binding_score == 1.0 ? 0.95 : 0.7

  score += binding_weight*binding_score + (1 - binding_weight)*docs_score

  # penalty if binding has no docs
  length(s.text) == 0 && (score *= 0.8)
  # penalty if binding isn't exported
  s.exported || (score *= 0.99)

  return score
end

function score_name(needle::String, s::DocObj)
  score = compare(Winkler(Jaro()), needle, s.name)

  s.exported || (score *= 0.99)
  length(s.text) == 0 && (score *= 0.99)

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

# improved rendering if used in Atom:
@require Juno begin
  @require Atom begin

    Juno.render(i::Juno.Inline, md::Base.Markdown.MD) = Juno.render(i, renderMD(md))

    function Juno.render(e::Juno.Editor, md::Base.Markdown.MD)
      mds = Atom.CodeTools.flatten(md)
      out = length(mds) == 1 ? Text(chomp(sprint(show, MIME"text/markdown"(), md))) :
                               Juno.Tree(Text("MD"), [Juno.render(e, renderMD(md))])
      Juno.render(e, out)
    end

    function Juno.render(i::Juno.Inline, d::DocObj)
      Juno.render(i, Juno.Tree(span(span(".syntax--support.syntax--function", d.name),
                                    span(" @ $(d.path):$(d.line)")), [Markdown.parse(d.text)]))
    end

    Atom.view(n::Hiccup.Node{:latex}) =
      Dict(:type  => :latex,
           :attrs => n.attrs,
           :text  => join(n.children, ' '))
  end
end

include("fuzzaldrin.jl")
include("introspective.jl")
include("finddocs.jl")
include("static.jl")
# include("db.jl")
include("precompile.jl")
include("documenter.jl")
include("rendermd.jl")
include("moduleinfo.jl")

_precompile_()

end # module
