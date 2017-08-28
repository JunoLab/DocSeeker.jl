function ispackage(mod)
  for f in readdir(Pkg.dir())
    f == mod && return true
  end
  return false
end

function modulesymbols(mod)
  syms = filter(x -> x.mod == mod, DocSeeker.alldocs())
  sort(syms, by = x -> x.name)[1:min(100, length(syms))]
end

function packageinfo(mod)
  Hiccup.div(
    renderMD(Markdown.parse(String(read(readmepath(mod))))),
    Hiccup.Node(:hr),
    Hiccup.h2("defined symbols:")
  ), modulesymbols(mod)
end

function moduleinfo(mod)
  header = if mod == "Core"
    renderMD("## Julia `Core`")
  elseif first(split(mod, '.')) == "Base"
    renderMD("## Julia Standard Library: `$mod`")
  else
    renderMD("## Module `$mod`")
  end

  header, modulesymbols(mod)
end

getmoduleinfo(mod) = ispackage(mod) ? packageinfo(mod) : moduleinfo(mod)
