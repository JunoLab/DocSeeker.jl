const dbpath = joinpath(@__DIR__, "..", "db", "usingdb")
const lockpath = joinpath(@__DIR__, "..", "db", "usingdb.lock")

function _createdocsdb()
  isfile(lockpath) && return

  open(lockpath, "w+") do io
    println(io, "locked")
  end

  # TODO: try looking for packages *not* in Pkg.dir()
  for pkg in readdir(Pkg.dir())
    @eval begin
      try
        using $(Symbol(pkg))
      end
    end
  end
  docs = alldocs()

  open(dbpath, "w+") do io
    serialize(io, docs)
  end

  rm(lockpath)
end

"""
    createdocsdb()

Asynchronously create a "database" of all local docstrings in `Pkg.dir()`.
This is done by loading all packages and using introspection to retrieve the docstrings --
the obvious limitation is that only packages that actually load without errors are considered.
"""
function createdocsdb()
  spawn(`julia -e "using DocSeeker; DocSeeker._createdocsdb()"`)
end

"""
    loaddocsdb() -> Vector{DocObj}

Retrieve the docstrings from the "database" created by `createdocsdb()`. Will return an empty
vector if the database is locked by `createdocsdb()`.
"""
function loaddocsdb()
  (isfile(lockpath) || !isfile(dbpath)) && return DocObj[]
  open(dbpath, "r") do io
    deserialize(io)
  end
end
