maindoccache = DocObj[]
maincachelastupdated = 0

function searchdocs(needle::String; loaded = true, mod::Module = Main, exportedonly = false)
  out = if loaded
    dynamicsearch(needle, mod)
  else
    dynamicsearch(needle, mod, loaddocsdb())
  end
  out = out[2]
  if exportedonly
    filter!(x -> x.exported, out)
  else
    out
  end
end

function dynamicsearch(needle::String, mod::Module = Main, docs = alldocs(mod))
  isempty(docs) && return ([], [])
  scores = score.(needle, docs)
  perm = sortperm(scores, rev=true)[1:min(20, length(docs))]
  scores[perm], docs[perm]
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
  global maindoccache, maincachelastupdated

  # main cache not regenerated more than once every 10s
  topmod == Main && time() - maincachelastupdated < 1e3 && return maindoccache

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
          text = join(d.text, ' ')
          html = sprint(Markdown.tohtml, MIME"text/html"(), Markdown.parse(text))
          dobj = DocObj(string(b.var), string(b.mod), string(determinetype(b.mod, b.var)),
                        # sig,
                        text, html, d.data[:path], d.data[:linenumber], expb)
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
  # update cache
  if topmod == Main
    maincachelastupdated = time()
    maindoccache = results
  end

  return results
end

function determinetype(mod, var)
  (isdefined(mod, var) && !Base.isdeprecated(mod, var)) || return ""

  b = getfield(mod, var)

  b isa Function && return "Function"

  string(typeof(b))
end
