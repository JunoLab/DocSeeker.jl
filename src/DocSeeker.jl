module DocSeeker

import Documenter: Utilities, DocSystem
import Base.Iterators: flatten
import Base.Docs: levenshtein

# TODO: Be a bit more intelligent about this.
function score(needle::String, s::String)
  words = split(s, ['\n', ' '])
  score = 0.0
  for w in words
    d = levenshtein(needle, w)
    d > 5 && continue
    score += 1/d
  end
  score
end

score(needle::String, s::Markdown.MD) = score(needle, Markdown.plain(s))

score(needle::String, s::Docs.DocStr) = score(needle, join(s.text, '\n'))

score(needle::String, s::Symbol) = score(needle, String(s))

score(needle::String, s) = 0.0

submodules(mod = Main) = filter!(m -> m != mod, Utilities.submodules(mod))

alldocs(mod = Main) = filter!(!isempty, DocSystem.getdocs.(allbindings(mod)))

allbindings(mod = Main) = collect(flatten(names.(collect(submodules()), true)))

function searchbinding(needle::String, mod::Module=Main)
  binds = allbindings(mod)
  scores = score.(needle, binds)
  perm = sortperm(scores, rev=true)[1:20]
  binds[perm]
end

function searchdocs(needle::String, mod::Module=Main)
  docs = collect(flatten(alldocs()))
  scores = score.(needle, docs)
  perm = sortperm(scores, rev=true)[1:20]
  [x.data[:binding] for x in docs[perm]]
end

end # module
