renderMD(md::Markdown.MD) = renderMD(md.content)

renderMD(md::Vector) = Hiccup.div([renderMD(x) for x in md], class = "markdown")

function renderMD{l}(header::Markdown.Header{l})
  Hiccup.Node(Symbol(:h, l), renderMDinline(header.text))
end

function renderMD(code::Markdown.Code)
  Hiccup.pre(
    Hiccup.code(code.code,
                class = !isempty(code.language) ? "language-$(code.language)" : "julia",
                block = true
    )
  )
end

function renderMD(md::Markdown.Paragraph)
  Hiccup.Node(:p, renderMDinline(md.content))
end

function renderMD(md::Markdown.BlockQuote)
  Hiccup.Node(:blockquote, renderMD(md.content))
end

function renderMD(md::Markdown.LaTeX)
  Hiccup.div(latex2katex(md.formula), class = "latex block")
end

function renderMD(f::Markdown.Footnote)
  Hiccup.div([
    Hiccup.Node(:p, f.id, class = "footnote-title"),
    renderMD(f.text)
  ], class = "footnote", id = "footnote-$(f.id)")
end

function renderMD(md::Markdown.Admonition)
  Hiccup.div([
    Hiccup.Node(:p, md.title, class = "admonition-title"),
    renderMD(md.content)
  ], class = "admonition $(md.category)")
end

function renderMD(md::Markdown.List)
  Hiccup.Node(Markdown.isordered(md) ? :ol : :ul, [Hiccup.li(renderMD(item)) for item in md.items],
              start = md.ordered > 1 ? string(md.ordered) : "")
end

function renderMD(md::Markdown.HorizontalRule)
  Hiccup.Node(:hr)
end

function renderMD(link::Markdown.Link)
  Hiccup.Node(:a, renderMDinline(link.text), href = link.url)
end

function renderMD(md::Markdown.Table)
  Hiccup.table([
    Hiccup.tr([Hiccup.Node(i == 1 ? :th : :td, renderMDinline(c)) for c in row])
    for (i, row) in enumerate(md.rows)
  ])
end

# Inline elements

function renderMDinline(content::Vector)
  [renderMDinline(x) for x in content]
end

function renderMDinline(code::Markdown.Code)
  Hiccup.code(code.code,
              class = !isempty(code.language) ? "language-$(code.language)" : "julia",
              block = false) # htmlesc?
end

function renderMDinline(md::Union{Symbol,AbstractString})
  md # htmlesc?
end

function renderMDinline(md::Markdown.Bold)
  Hiccup.strong(renderMDinline(md.text))
end

function renderMDinline(md::Markdown.Italic)
  Hiccup.Node(:em, renderMDinline(md.text))
end

function renderMDinline(md::Markdown.Image)
  Hiccup.img(src = md.url, alt = md.alt)
end

function renderMDinline(f::Markdown.Footnote)
  Hiccup.Node(:a, Hiccup.span("[$(f.id)]"), href = "#footnote-$(f.id)", class = "footnote")
end

function renderMDinline(link::Markdown.Link)
  Hiccup.Node(:a, renderMDinline(link.text), href = link.url)
end

function renderMDinline(md::Markdown.LaTeX)
  Hiccup.span(latex2katex(md.formula), class = "latex inline")
end

function renderMDinline(br::Markdown.LineBreak)
  Hiccup.Node(:br)
end

# katex doesn't support certain latex expressions. Need to transform those to something
# that *is* supported or get rid of them altogether.
function latex2katex(code)
  code = replace(code, "\\operatorname", "\\mathrm")
  code
end
