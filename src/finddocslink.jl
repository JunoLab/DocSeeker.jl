# search a package's readme for links to documentation
function finddocsURL(pkg)
  pkgpath = Pkg.dir(pkg)
  isdir(pkgpath) || error("Package $pkg not installed.")

  readmepath = joinpath(pkgpath, "README.md")
  isfile(readmepath) || return Markdown.Link[]

  md = Markdown.parse(String(read(joinpath(pkgpath, "README.md"))))
  links = findlinks(md)
  doclinks = Markdown.Link[]
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
