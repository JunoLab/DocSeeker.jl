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

    pkgs = keys(Pkg.installed())
    if isdefined(Main, :Juno) && Juno.isactive()
      Juno.progress(name="Documentation Cache") do p
        for (i, pkg) in enumerate(pkgs)
          wait(spawn(`$(Base.julia_cmd()) -e "using DocSeeker; DocSeeker._createdocsdb(\"$(pkg)\")"`))
          Juno.progress(p, i/length(pkgs))
          Juno.msg(p, pkg)
        end
      end
    else
      for (i, pkg) in enumerate(pkgs)
        wait(spawn(`$(Base.julia_cmd()) -e "using DocSeeker; DocSeeker._createdocsdb(\"$(pkg)\")"`))
      end
    end
  finally
    rm(lockpath)
  end
end

using IterTools: chain

function _createdocsdb(pkg)
  try
    @eval using $(Symbol(pkg))
  end
  docs = alldocs()

  docs_old = isfile(dbpath) ?
    open(dbpath, "r") do io
      deserialize(io)
    end : []

  docs = unique(chain(docs_old, docs))

  open(dbpath, "w+") do io
    serialize(io, docs)
  end
end

"""
    createdocsdb()

Asynchronously create a "database" of all local docstrings in `Pkg.dir()`.
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

Retrieve the docstrings from the "database" created by `createdocsdb()`. Will return an empty
vector if the database is locked by `createdocsdb()`.
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
