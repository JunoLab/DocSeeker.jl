using Pkg
using Base.Iterators: flatten
using Serialization: serialize, deserialize

include("utils.jl")

const PROGRESS_ID = "docseeker_progress"
const DB_DIR = joinpath(@__DIR__, "..", "db")
"""
    DOC_DB_CACHE::Vector{DocObj}

Database of docstrings that is supposed to be created by [`createdocsdb`](@ref).
"""
const DOC_DB_CACHE = DocObj[]
const DB_TASK = Ref{Union{Nothing,Task}}(nothing)

function _createdocsdb()
  @info "Docs" progress=0 _id=PROGRESS_ID
  PKGSDONE[] = 0
  try
    pkgs = if isdefined(Pkg, :dependencies)
      getfield.(values(Pkg.dependencies()), :name)
    else
      collect(keys(Pkg.installed()))
    end
    pushfirst!(pkgs, "Base")
    ondone = (i, el) -> progress_callback(i, el, pkgs)
    run_queued(docdb_wrapper, pkgs, ondone = ondone)
  catch err
    @error err
  finally
    @info "Docs: Refreshing database" progress=1-(1/1_000_000) _id=PROGRESS_ID
    refreshdb!() # refresh database
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
  DB_TASK[] = @async _createdocsdb()
  nothing
end

"""
    loaddocsdb() -> Vector{DocObj}

Retrieve the docstrings from [`DOC_DB_CACHE`](@ref).
"""
function loaddocsdb()
  if DB_TASK[] !== nothing && !istaskdone(DB_TASK[])
    @warn "Doc cache is being created by `DocSeeker.createdocsdb()`."
  end
  isempty(DOC_DB_CACHE) && refreshdb!()
  isempty(DOC_DB_CACHE) &&
    throw(ErrorException("Please regenerate the doc cache by calling `DocSeeker.createdocsdb()`."))
  return DOC_DB_CACHE
end

"""
    refreshdb!()

Refresh [`DOC_DB_CACHE`](@ref).
"""
function refreshdb!()
  empty!(DOC_DB_CACHE)
  for file in readdir(DB_DIR)
    endswith(file, ".db") || continue
    try
      append!(DOC_DB_CACHE, deserialize(joinpath(DB_DIR, file)))
    catch err
      # @error err, file
    end
  end
  unique!(DOC_DB_CACHE)
end
