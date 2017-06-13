using JLD, FileIO

const dbpath = joinpath(@__DIR__, "..", "db", "usingdb.jld")

function createdocsdb()
  for pkg in readdir(Pkg.dir())
    @eval begin
      try
        using $(Symbol(pkg))
      end
    end
  end
  docs = alldocs()
  save(File(format"JLD", dbpath), "d", d)
  nothing
end

function loaddocsdb()
  JLD.read(dbpath, "d")
end
