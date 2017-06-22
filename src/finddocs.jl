using URIParser, DataFrames

jlhome() = ccall(:jl_get_julia_home, Any, ())

function basepath(file)
  srcdir = joinpath(jlhome(),"..","..")
  releasedir = joinpath(jlhome(),"..","share","julia")
  normpath(joinpath(isdir(srcdir) ? srcdir : releasedir, file))
end

"""
    docsdir(pkg) -> String

Find the directory conataining the documenatation for package `pkg`. Will fall back to
returning a documentation URL in the package's README.md.
"""
function docsdir(pkg)
  # sepcial case base
  lowercase(pkg) == "base" && return joinpath(basepath("doc"), "src")

  pkgpath = Pkg.dir(pkg)
  # package not installed
  isdir(pkgpath) || return ""

  # Documenter.jl default:
  docpath = joinpath(pkgpath, "docs", "src")
  isdir(docpath) && return docpath

  # other possibility:
  docpath = joinpath(pkgpath, "doc", "src")
  isdir(docpath) && return docpath

  # fallback to link
  baseURL(finddocsURL(pkg))
end


"""
    baseURL(links::Vector{Markdown.Link}) -> String

Find the most common host and return the first URL in `links` with that host.
"""
function baseURL(links::Vector{Markdown.Link})
  isempty(links) && return ""

  length(links) == 1 && return links[1].url

  # find biggest most common host
  urls = map(x -> URI(x.url), links)
  hosts = String[url.host for url in urls]
  perm = sortperm([(host, count(x -> x == host, hosts)) for host in unique(hosts)], lt = (x,y) -> x[2] > y[2])

  # TODO: better heuristic for choosing the right path
  links[perm[1]].url
end

"""
    finddocsURL(pkg) -> Vector{Markdown.Link}

Search `pkg`s readme for links to documentation.
"""
function finddocsURL(pkg)
  lowercase(pkg) == "base" && return [Markdown.Link("", "https://docs.julialang.org")]
  pkgpath = Pkg.dir(pkg)
  doclinks = Markdown.Link[]
  isdir(pkgpath) || return doclinks

  readmepath = joinpath(pkgpath, "README.md")
  isfile(readmepath) || return doclinks

  md = Markdown.parse(String(read(joinpath(pkgpath, "README.md"))))
  links = findlinks(md)

  for link in links
    if isdoclink(link)
      push!(doclinks, link)
    end
  end
  doclinks
end

function isdoclink(link::Markdown.Link)
  p = lowercase(Markdown.plaininline(link))
  contains(p, "docs") || contains(p, "documentation")
end

function findlinks(mdobj)
  doclinks = Markdown.Link[]
  for obj in mdobj.content
    findlinks(obj, doclinks)
  end
  doclinks
end

function findlinks(mdobj::Markdown.Paragraph, links)
  for obj in mdobj.content
    findlinks(obj, links)
  end
end

findlinks(mdobj, links) = nothing
findlinks(mdobj::Markdown.Link, links) = push!(links, mdobj)
