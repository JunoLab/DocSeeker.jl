cache = Dict{String, Tuple{Float64, Vector{DocObj}}}()
CACHETIMEOUT = 30 # s

# TODO: change `mod` argument to string or symbol, so that this actually works with the
#       docsdb. Also potentially filter the module after searching, instead of before.
function searchdocs(needle::String; loaded = true, mod::Module = Main, exportedonly = false)
  out = if loaded
    dynamicsearch(needle, mod)
  else
    dynamicsearch(needle, mod, loaddocsdb())
  end
  if exportedonly
    filter!(x -> x[2].exported, out)
  else
    out
  end
end

function dynamicsearch(needle::String, mod::Module = Main, docs = alldocs(mod))
  isempty(docs) && return ([], [])
  scores = zeros(size(docs))
  Threads.@threads for i in eachindex(docs)
    scores[i] = score(needle, docs[i])
  end
  perm = sortperm(scores, rev=true)[1:min(20, length(docs))]
  [(scores[p], docs[p]) for p in perm]
end

function modulebindings(mod, exportedonly = false, binds = Dict{Module, Vector{Symbol}}(), seenmods = Set{Module}())
  for name in names(mod, !exportedonly, !exportedonly)
    startswith(string(name), '#') && continue
    if isdefined(mod, name) && !Base.isdeprecated(mod, name)
      obj = getfield(mod, name)
      !haskey(binds, mod) && (binds[mod] = [])
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
    alldocs(mod = Main) -> Vector{DocObj}

Find all docstrings in module `mod` and it's submodules.
"""
function alldocs(topmod = Main)
  stopmod = string(topmod)
  if haskey(cache, stopmod) && (time() - cache[stopmod][1]) < CACHETIMEOUT
    return cache[stopmod][2]
  end

  results = DocObj[]
  # all bindings
  modbinds = modulebindings(topmod, false)
  # exported bindings only
  exported = modulebindings(topmod, true)
  for mod in keys(modbinds)
    parentmod = module_parent(mod)
    meta = Docs.meta(mod)
    for name in modbinds[mod]
      b = Docs.Binding(mod, name)
      # figure out how to do this properly...
      expb = (haskey(exported, mod) && (name in exported[mod])) ||
             (haskey(exported, parentmod) && (name in exported[parentmod]))

      if haskey(meta, b)
        multidoc = meta[b]
        for sig in multidoc.order
          d = multidoc.docs[sig]
          text = Markdown.parse(join(d.text, ' '))
          html = sprint(Markdown.tohtml, MIME"text/html"(), text)
          # TODO: might sometimes throw a `MethodError: no method matching stripmd(::Symbol)`
          text = lowercase(Docs.stripmd(text))
          path = d.data[:path] == nothing ? "<unknown>" : d.data[:path]
          dobj = DocObj(string(b.var), string(b.mod), string(determinetype(b.mod, b.var)),
                        # sig,
                        text, html, path, d.data[:linenumber], expb)
          push!(results, dobj)
        end
      elseif isdefined(mod, name) && !Base.isdeprecated(mod, name) && name != :Vararg
        bind = getfield(mod, name)
        meths = methods(bind)
        if !isempty(meths)
          for m in meths
            dobj = DocObj(string(name), string(mod), string(determinetype(mod, name)),
                          "", "", m.file, m.line, expb)
            push!(results, dobj)
          end
        else
          dobj = DocObj(string(name), string(mod), string(determinetype(mod, name)),
                        "", "", "<unknown>", 0, expb)
          push!(results, dobj)
        end
      end
    end
  end
  results = unique(results)

  # update cache
  cache[stopmod] = (time(), results)

  return results
end

function determinetype(mod, var)
  (isdefined(mod, var) && !Base.isdeprecated(mod, var)) || return ""

  b = getfield(mod, var)

  b isa Function && return "Function"

  string(typeof(b))
end
