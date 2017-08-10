using URIParser

jlhome() = ccall(:jl_get_julia_home, Any, ())

function basepath(files...)
  srcdir = joinpath(jlhome(), "..", "..")
  releasedir = joinpath(jlhome(), "..", "share", "julia")
  normpath(joinpath(isdir(srcdir) ? srcdir : releasedir, files...))
end

"""
    docsdir(pkg) -> String

Find the directory conataining the documenatation for package `pkg`. Will fall back to
returning a package's README.md. Returns an empty `String` if no indication of documentation
is found.
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

  # fallback to readme
  readmepath = joinpath(pkgpath, "README.md")
  return isfile(readmepath) ? readmepath : ""
end

function readmepath(pkg)
  (lowercase(pkg) == base) && return ""

  pkgpath = Pkg.dir(pkg)
  # package not installed
  isdir(pkgpath) || return ""
  joinpath(pkgpath, "README.md")
end

"""
    docsurl(pkg) -> String

Return the most likely candidate for a package's online documentation or an empty string.
"""
docsurl(pkg) = baseURL(finddocsURL(pkg))

"""
    baseURL(links::Vector{Markdown.Link}) -> String

Find the most common host and return the first URL in `links` with that host.
"""
function baseURL(links::Vector{Markdown.Link})
  isempty(links) && return ""

  length(links) == 1 && return links[1].url

  # find most common host
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

  isempty(links) && (links = findplainlinks(md))

  for link in links
    if isdoclink(link)
      push!(doclinks, link)
    end
  end
  doclinks
end

function findplainlinks(md)
  text = Markdown.plain(md)
  [Markdown.Link(link, link) for link in matchall(r"(https?:\/\/[^\s]+)\b", text)]
end

function isdoclink(link::Markdown.Link)
  p = lowercase(Markdown.plaininline(link))
  # TODO: could be a bit smarter about this
  contains(p, "docs") || contains(p, "documentation") ||
    contains(p, "/stable") || contains(p, "/latest")
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
