using JLD, FileIO

const dbpath = joinpath(@__DIR__, "..", "db", "usingdb.jld")

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

function createdocsdb()
  run(`julia -e "using DocSeeker; DocSeeker._createdocsdb()"`)
end

function loaddocsdb()
  open(dbpath, "r") do io
    deserialize(io)
  end
end
