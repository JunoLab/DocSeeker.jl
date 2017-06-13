function dynamicsearch(needle::String, mod::Module = Main)
  docs = collect(alldocs(mod))
  scores = score.(needle, docs)
  perm = sortperm(scores, rev=true)[1:20]
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
