
maindoccache = DocObj[]
maincachelastupdated = time()


function dynamicsearch(needle::String, mod::Module = Main)
  docs = collect(alldocs(mod))
  isempty(docs) && return ([], [])
  scores = score.(needle, docs)
  perm = sortperm(scores, rev=true)[1:min(20, length(docs))]
  scores[perm], docs[perm]
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

"""
    alldocs(mod = Main) -> Vector{DocObj}

Find all docstrings in module `mod` and it's submodules.
"""
function alldocs(mod = Main)
  global maindoccache, maincachelastupdated

  # main cache not regenerated more than once every 10s
  mod == Main && time() - maincachelastupdated < 1e4 && return maindoccache

  results = DocObj[]
  modbinds = modulebindings(mod)
  for mod in keys(modbinds)
    meta = Docs.meta(mod)
    for (binding, multidoc) in meta
      for sig in multidoc.order
        d = multidoc.docs[sig]
        var = binding.var
        mod = binding.mod
        dobj = DocObj(string(var), string(mod), string(determinetype(mod, var)),
                      sig, join(d.text, ' '), d.data[:path], d.data[:linenumber])
        push!(results, dobj)
      end
    end
  end
  if mod == Main
    maincachelastupdated = time()
    maindoccache = results
  end
  results
end

function determinetype(mod, var)
  b = getfield(mod, var)

  b isa Function && return "Function"

  string(typeof(b))
end
