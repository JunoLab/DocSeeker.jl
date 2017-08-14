CACHE = Dict{String, Tuple{Float64, Vector{DocObj}}}()
CACHETIMEOUT = 30 # s

MAX_RETURN_SIZE = 20 # how many results to return at most


function searchdocs(needle::String; loaded = true, mod = "Main",
                    maxreturns = MAX_RETURN_SIZE, exportedonly = false)
  loaded ? dynamicsearch(needle, mod, exportedonly, maxreturns) :
           dynamicsearch(needle, mod, exportedonly, maxreturns, loaddocsdb())
end

function dynamicsearch(needle::String, mod = "Main", exportedonly = false,
                       maxreturns = MAX_RETURN_SIZE, docs = alldocs())
  isempty(docs) && return []
  scores = zeros(size(docs))
  Threads.@threads for i in eachindex(docs)
    scores[i] = score(needle, docs[i])
  end
  perm = sortperm(scores, rev=true)
  out = [(scores[p], docs[p]) for p in perm]

  f = if exportedonly
    if mod ≠ "Main"
      x -> x[2].exported && x[2].mod == mod
    else
      x -> x[2].exported
    end
  else
    if mod ≠ "Main"
      x -> x[2].mod == mod
    else
      x -> true
    end
  end

  filter!(f, out)

  out[1:min(length(out), maxreturns)]
end

function modulebindings(mod, exportedonly = false, binds = Dict{Module, Set{Symbol}}(), seenmods = Set{Module}())
  for name in names(mod, !exportedonly, !exportedonly)
    startswith(string(name), '#') && continue
    if isdefined(mod, name) && !Base.isdeprecated(mod, name)
      obj = getfield(mod, name)
      !haskey(binds, mod) && (binds[mod] = Set{Symbol}())
      push!(binds[mod], name)
      if (obj isa Module) && !(obj in seenmods)
        push!(seenmods, obj)
        modulebindings(obj, exportedonly, binds, seenmods)
      end
    end
  end
  return binds
end

"""
    alldocs() -> Vector{DocObj}

Find all docstrings in module `mod` and it's submodules.
"""
function alldocs()
  topmod = Main
  stopmod = string(topmod)
  if haskey(CACHE, stopmod) && (time() - CACHE[stopmod][1]) < CACHETIMEOUT
    return CACHE[stopmod][2]
  end

  results = DocObj[]
  # all bindings
  modbinds = modulebindings(topmod, false)
  # exported bindings only
  exported = modulebindings(topmod, true)

  # loop over all loaded modules
  for mod in keys(modbinds)
    parentmod = module_parent(mod)
    meta = Docs.meta(mod)

    # loop over all names handled by the docsystem
    for b in keys(meta)
      # kick everything out that is handled by the docsystem
      haskey(modbinds, mod) && delete!(modbinds[mod], b.var)
      haskey(exported, mod) && delete!(exported[mod], b.var)

      expb = (haskey(exported, mod) && (b.var in exported[mod])) ||
             (haskey(exported, parentmod) && (b.var in exported[parentmod]))

      multidoc = meta[b]
      for sig in multidoc.order
        d = multidoc.docs[sig]
        text = Markdown.parse(join(d.text, ' '))
        html = renderMD(text)
        text = Docs.stripmd(text)
        path = d.data[:path] == nothing ? "<unknown>" : d.data[:path]
        dobj = DocObj(string(b.var), string(b.mod), string(determinetype(b.mod, b.var)),
                      # sig,
                      text, html, path, d.data[:linenumber], expb)

        push!(results, dobj)
      end
    end

    # resolve everything that is not caught by the docsystem
    for name in modbinds[mod]
      b = Docs.Binding(mod, name)

      # figure out how to do this properly...
      expb = (haskey(exported, mod) && (name in exported[mod])) ||
             (haskey(exported, parentmod) && (name in exported[parentmod]))

      if isdefined(mod, name) && !Base.isdeprecated(mod, name) && name != :Vararg
        # TODO: For now we don't need this -> free 50% speedup.
        # bind = getfield(mod, name)
        # meths = methods(bind)
        # if !isempty(meths)
        #   for m in meths
        #     dobj = DocObj(string(name), string(mod), string(determinetype(mod, name)),
        #                   "", Hiccup.div(), m.file, m.line, expb)
        #     push!(results, dobj)
        #   end
        # else
          dobj = DocObj(string(name), string(mod), string(determinetype(mod, name)),
                        "", Hiccup.div(), "<unknown>", 0, expb)
          push!(results, dobj)
        # end
      end
    end
  end
  results = unique(results)

  # update cache
  CACHE[stopmod] = (time(), results)

  return results
end

function determinetype(mod, var)
  (isdefined(mod, var) && !Base.isdeprecated(mod, var)) || return ""

  b = getfield(mod, var)

  b isa Function && return "Function"

  string(typeof(b))
end
