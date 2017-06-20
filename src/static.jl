const dbpath = joinpath(@__DIR__, "..", "db", "usingdb")

function _createdocsdb()
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

Retrieve the docstrings from the "database" created by `createdocsdb()`.
"""
function loaddocsdb()
  open(dbpath, "r") do io
    deserialize(io)
  end
end
