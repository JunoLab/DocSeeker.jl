module DocSeeker

using StringDistances
using Juno

# TODO: better string preprocessing.
function score(needle::String, s::Docs.DocStr)
  length(s.text) == 0 && return 0.0
  binding = split(string(get(s.data, :binding, "")), '.')[end]
  doc = lowercase(join(s.text, ' '))
  (2*compare(Hamming(), needle, binding) + compare(TokenMax(Hamming()), lowercase(needle), doc))/3
end

function modulebindings(mod, binds = Dict{Module, Vector{Symbol}}(), seenmods = Set{Module}())
  for name in names(mod, true)
    if isdefined(mod, name) && !Base.isdeprecated(mod, name)
      obj = getfield(mod, name)
      !haskey(binds, mod) && (binds[mod] = [])
      push!(binds[mod], name)
      if (obj isa Module) && !(obj in seenmods)
        push!(seenmods, obj)
        modulebindings(obj, binds, seenmods)
      end
    end
  end
  return binds
end

function alldocs(mod = Main)
  results = Docs.DocStr[]
  modbinds = modulebindings(mod)
  for mod in keys(modbinds)
    meta = Docs.meta(mod)
    for (binding, multidoc) in meta
      for sig in multidoc.order
        d = multidoc.docs[sig]
        d.data[:binding] = binding
        push!(results, d)
      end
    end
  end
  results
end

# TODO: Search through pkgdir/docs
function Base.search(needle::String, mod::Module = Main)
  docs = collect(alldocs(mod))
  scores = score.(needle, docs)
  perm = sortperm(scores, rev=true)[1:20]
  scores[perm], docs[perm]
end

# search a package's readme for links to documentation
function finddocsURL(pkg)
  pkgpath = Pkg.dir(pkg)
  isdir(pkgpath) || error("Package $pkg not installed.")

  readmepath = joinpath(pkgpath, "README.md")
  isfile(readmepath) || return Markdown.Link[]

  md = Markdown.parse(String(read(joinpath(pkgpath, "README.md"))))
  links = findlinks(md)
  doclinks = Markdown.Link[]
  for link in links
    if isdoclink(link)
      push!(doclinks, link)
    end
  end
  doclinks
end

function isdoclink(link::Markdown.Link)
  p = lowercase(Markdown.plaininline(link))
  contains(p, "docs") || contains(p, "documentation")
end

function findlinks(mdobj)
  doclinks = Markdown.Link[]
  for obj in mdobj.content
    findlinks(obj, doclinks)
  end
  doclinks
end

function findlinks(mdobj::Markdown.Paragraph, links)
  for obj in mdobj.content
    findlinks(obj, links)
  end
end

findlinks(mdobj, links) = nothing
findlinks(mdobj::Markdown.Link, links) = push!(links, mdobj)

# rendering methods
function Juno.render(i::Juno.Inline, d::Docs.DocStr)
  Juno.render(i, Juno.Tree(d.data[:binding], [Text(join(d.text, ' '))]))
end

end # module
