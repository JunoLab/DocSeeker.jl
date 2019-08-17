using Pkg: installed
using Distributed: @spawn
using Base.Iterators: flatten
using Serialization: serialize, deserialize

const dbpath = joinpath(@__DIR__, "..", "db", "usingdb")
const lockpath = joinpath(@__DIR__, "..", "db", "usingdb.lock")

DOCDBCACHE = DocObj[]

function _createdocsdb()
  isfile(lockpath) && return

  open(lockpath, "w+") do io
    println(io, "locked")
  end

  try
    isfile(dbpath) && rm(dbpath)

    pkgs = keys(installed())

    if isdefined(Main, :Juno)
      @eval import Juno
      Juno.isactive() && begin
        Juno.progress() do id
          for (i, pkg) in enumerate(pkgs)
            @info "caching documentations of $(pkg) ..." progress = i / length(pkgs) _id = id
            process = @spawn _createdocsdb(pkg)
            wait(process)
          end
        end
      end
    else
      for (i, pkg) in enumerate(pkgs)
        @info "caching documentations of $(pkg) ..."
        process = @spawn _createdocsdb(pkg)
        wait(process)
      end
    end
  catch err
    @error err
  finally
    rm(lockpath)
  end
end

function _createdocsdb(pkg)
  try
    @eval using $(Symbol(pkg))
  catch err
    @error err
    return
  end

  docs_old = isfile(dbpath) ?
    open(dbpath, "r") do io
      deserialize(io)
    end : []
  docs = unique(flatten((docs_old, alldocs())))

  open(dbpath, "w+") do io
    serialize(io, docs)
  end
end

"""
    createdocsdb()

Asynchronously create a "database" of all local docstrings in [`Pkg.installed()`](@ref).
This is done by loading all packages and using introspection to retrieve the docstrings --
the obvious limitation is that only packages that actually load without errors are considered.
"""
function createdocsdb()
  isfile(dbpath) && rm(dbpath)
  isfile(lockpath) && rm(lockpath)
  @async _createdocsdb()
  nothing
end

"""
    loaddocsdb() -> Vector{DocObj}

Retrieve the docstrings from the "database" created by [`createdocsdb()`](@ref).
Will return an empty vector if the database is locked by [`createdocsdb()`](@ref).
"""
function loaddocsdb()
  global DOCDBCACHE
  isempty(DOCDBCACHE) && (DOCDBCACHE = _loaddocsdb())
  length(DOCDBCACHE) == 0 &&
    throw(ErrorException("Please regenerate the doc cache by calling `DocSeeker.createdocsdb()`."))
  DOCDBCACHE
end

function _loaddocsdb()
  (isfile(lockpath) || !isfile(dbpath)) && return DocObj[]
  open(dbpath, "r") do io
    deserialize(io)
  end
end
