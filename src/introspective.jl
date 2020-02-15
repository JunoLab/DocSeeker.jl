CACHE = (0, [])
CACHETIMEOUT = 30 # s

MAX_RETURN_SIZE = 20 # how many results to return at most

function searchdocs(needle::AbstractString; loaded::Bool = true, mod::Module = Main,
                    maxreturns::Int = MAX_RETURN_SIZE, exportedonly::Bool = false,
                    name_only::Bool = false)
  loaded ? dynamicsearch(needle, mod, exportedonly, maxreturns, name_only) :
           dynamicsearch(needle, mod, exportedonly, maxreturns, name_only, loaddocsdb())
end

# TODO:
# We may want something like `CodeTools.getmodule` here, so that we can accept `mod` as `String`:
# - then we can correctly score bindings even in unloaded packages
# - it would make `isdefined` checks below more robust -- currently it won't work when e.g.
#   we try to find `Atom.JunoDebugger.isdebugging` given `mod == Atom`
function dynamicsearch(needle::AbstractString, mod::Module = Main,
                       exportedonly::Bool = false, maxreturns::Int = MAX_RETURN_SIZE,
                       name_only::Bool = false, docs::Vector{DocObj} = alldocs(mod))
  isempty(docs) && return DocObj[]
  scores = zeros(size(docs))
  modstr = string(mod)
  Threads.@threads for i in eachindex(docs)
    scores[i] = score(needle, docs[i], modstr, name_only)
  end
  perm = sortperm(scores, rev=true)
  out = [(scores[p], docs[p]) for p in perm]

  f = if exportedonly
    if mod == Main
      x -> x[2].exported
    else
      let mod = mod, modstr = modstr
        x -> begin
          # filters out unexported bindings
          x[2].exported &&
          # filters bindings that can be reached from `mod`
          (
            isdefined(mod, Symbol(x[2].mod)) ||
            modstr == x[2].mod # needed since submodules are not defined in themselves
          )
        end
      end
    end
  else
    if mod == Main
      x -> true
    else
      let mod = mod, modstr = modstr
        x -> begin
          # filters bindings that can be reached from `mod`
          isdefined(mod, Symbol(x[2].mod)) ||
          modstr == x[2].mod # needed since submodules are not defined in themselves
        end
      end
    end
  end
  filter!(f, out)

  return out[1:min(length(out), maxreturns)]
end

function modulebindings(mod, exportedonly = false, binds = Dict{Module, Set{Symbol}}(), seenmods = Set{Module}())
  # This does fairly stupid things, but whatever. Works for now.
  for mod in Base.loaded_modules_array()
    mod in seenmods && continue
    push!(seenmods, mod)
    modulebindings(mod, exportedonly, binds, seenmods)
  end

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
    alldocs(topmod = Main) -> Vector{DocObj}

Find all docstrings in all currently loaded Modules.
"""
function alldocs(topmod = Main)
  global CACHE

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
