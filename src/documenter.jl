function load_documenter_docs(pkg)
  docs = docsdir(pkg)
  isempty(docs) && return []

  getfiles(docs)
end

function getfiles(path, files = Tuple{String, String}[])
  isdir(path) || return files
  for f in readdir(path)
    f = joinpath(path, f)
    if isfile(f) && split(f, '.')[end] == "md"
      push!(files, (f, read(f)))
    elseif isdir(f)
      getfiles(f, files)
    end
  end
  files
end

function searchfiles(needle, files::Tuple{String, String})
  scores = Float64[]

  for (path, content) in files
    push!(scores, compare(TokenSet(Jaro()), needle, content))
  end
  p = sortperm(scores, rev=true)[1:min(20, length(scores))]
  scores[p], files[p]
end

searchfiles(needle, pkg::String) = searchfiles(load_documenter_docs(pkg))

function searchfiles(needle)
  files = Tuple{String, String}[]
  for pkg in readdir(Pkg.dir())
    @show pkg
    isdir(pkg) || continue
    @show pkg
    append!(files, load_documenter_docs(pkg))
  end

  searchfiles(needle, files)
end
