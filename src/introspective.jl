CACHE = (0, [])
CACHETIMEOUT = 30 # s

MAX_RETURN_SIZE = 20 # how many results to return at most


function searchdocs(needle::String; loaded = true, mod = "Main",
                    maxreturns = MAX_RETURN_SIZE, exportedonly = false,
                    name_only = false)
  loaded ? dynamicsearch(needle, mod, exportedonly, maxreturns, name_only) :
           dynamicsearch(needle, mod, exportedonly, maxreturns, name_only, loaddocsdb())
end

function dynamicsearch(needle::String, mod = "Main", exportedonly = false,
                       maxreturns = MAX_RETURN_SIZE, name_only = false,
                       docs = alldocs())
  isempty(docs) && return []
  scores = zeros(size(docs))
  Threads.@threads for i in eachindex(docs)
    scores[i] = score(needle, docs[i], name_only)
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
  for name in names(mod, all=!exportedonly, imported=!exportedonly)
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

Find all docstrings in all currently loaded Modules.
"""
function alldocs()
  global CACHE

  topmod = Main
  if (time() - CACHE[1]) < CACHETIMEOUT
    return CACHE[2]
  end

  results = DocObj[]
  # all bindings
  modbinds = modulebindings(topmod, false)
  # exported bindings only
  exported = modulebindings(topmod, true)

  # loop over all loaded modules
  for mod in keys(modbinds)
    parentmod = parentmodule(mod)
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
        md = Markdown.parse(join(d.text, ' '))
        text = stripmd(md)
        path = d.data[:path] == nothing ? "<unknown>" : d.data[:path]
        dobj = DocObj(string(b.var), string(b.mod), string(determinetype(b.mod, b.var)),
                      # sig,
                      text, md, path, d.data[:linenumber], expb)
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
        # HACK: For now we don't need this -> free 50% speedup.
        # bind = getfield(mod, name)
        # meths = methods(bind)
        # if !isempty(meths)
        #   for m in meths
        #     dobj = DocObj(string(name), string(mod), string(determinetype(mod, name)),
        #                   "", Hiccup.div(), m.file, m.line, expb)
        #     push!(results, dobj)
        #   end
        # else
        #   dobj = DocObj(string(name), string(mod), string(determinetype(mod, name)),
        #                 "", Markdown.parse(""), "<unknown>", 0, expb)
        #   push!(results, dobj)
        # end
        dobj = DocObj(string(name), string(mod), string(determinetype(mod, name)),
                      "", Markdown.parse(""), "<unknown>", 0, expb)
        push!(results, dobj)
      end
    end
  end
  append!(results, keywords())
  results = unique(results)

  # update cache
  CACHE = (time(), results)

  return results
end

function keywords()
  out = DocObj[]
  for k in keys(Docs.keywords)
    d = Docs.keywords[k]
    md = Markdown.parse(join(d.text, ' '))
    text = stripmd(md)
    dobj = DocObj(string(k), "Base", "Keyword", text, md, "", 0, true)
    push!(out, dobj)
  end
  return out
end

function determinetype(mod, var)
  (isdefined(mod, var) && !Base.isdeprecated(mod, var)) || return ""

  b = getfield(mod, var)

  b isa Function && return "Function"
  b isa UnionAll && return "DataType"

  string(typeof(b))
end
