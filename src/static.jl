using Pkg: installed
using Base.Iterators: flatten
using Serialization: serialize, deserialize

include("utils.jl")

const PROGRESS_ID = "docseeker_progress"
DOCDBCACHE = DocObj[]

function _createdocsdb()
  @info "Docs" progress=0 _id=PROGRESS_ID
  PKGSDONE[] = 0
  try
    pkgs = collect(keys(installed()))
    pushfirst!(pkgs, "Base")
    ondone = (i, el) -> progress_callback(i, el, pkgs)
    run_queued(docdb_wrapper, pkgs, ondone = ondone)
  catch err
    @error err
  finally
    @info "" progress=1 _id=PROGRESS_ID
  end
end

const PKGSDONE = Ref(0)
function progress_callback(i, el, pkgs)
  total = length(pkgs)
  PKGSDONE[] += 1
  @info "Docs: $el ($(PKGSDONE[])/$total)" progress=PKGSDONE[]/total _id=PROGRESS_ID
end

function docdb_wrapper(pkg)
  workerfile = joinpath(@__DIR__, "create_db.jl")
  env = dirname(Base.active_project())
  cmd = `$(first(Base.julia_cmd())) --compiled-modules=no -O0 $workerfile $pkg $env`
  logfile = joinpath(@__DIR__, "..", "db", string(pkg, "-", hash(env), ".log"))
  return cmd, Dict(:log=>logfile)
end

"""
    createdocsdb()

Asynchronously create a "database" of all local docstrings in [`Pkg.installed()`](@ref).
This is done by loading all packages and using introspection to retrieve the docstrings --
the obvious limitation is that only packages that actually load without errors are considered.
"""
function createdocsdb()
  dbdir = joinpath(@__DIR__, "..", "db")
  for file in readdir(dbdir)
    if endswith(file, ".db") || endswith(file, ".log")
      rm(joinpath(dbdir, file))
    end
  end
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
  dbdir = joinpath(@__DIR__, "..", "db")
  docs = DocObj[]
  for file in readdir(dbdir)
    endswith(file, ".db") || continue
    try
      append!(docs, deserialize(joinpath(dbdir, file)))
    catch err
      # @error err, file
    end
  end
  unique!(docs)
  return docs
end
