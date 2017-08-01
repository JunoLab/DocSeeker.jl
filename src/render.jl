renderMD(md::Markdown.MD) = renderMD(md.content)

renderMD(md::Vector) = Hiccup.div([renderMD(x) for x in md], class = "markdown")

function renderMD{l}(header::Markdown.Header{l})
  Hiccup.Node(Symbol(:h, l), renderMDinline(header.text))
end

function renderMD(code::Markdown.Code)
  Hiccup.pre(
    Hiccup.code(code.code,
                class = !isempty(code.language) ? "language-$(code.language)" : ""
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
  Hiccup.div(md.formula, class = "latex block")
end

function renderMD(f::Markdown.Footnote)
    # withtag(io, :div, :class => "footnote", :id => "footnote-$(f.id)") do
    #     withtag(io, :p, :class => "footnote-title") do
    #         print(io, f.id)
    #     end
    #     html(io, f.text)
    # end
end

function renderMD(md::Markdown.Admonition)
    # withtag(io, :div, :class => "admonition $(md.category)") do
    #     withtag(io, :p, :class => "admonition-title") do
    #         print(io, md.title)
    #     end
    #     html(io, md.content)
    # end
end

function renderMD(md::Markdown.List)
    Hiccup.Node(Markdown.isordered(md) ? :ol : :ul, [Hiccup.li(item) for item in md.items],
                start = md.ordered > 1 ? string(md.ordered) : "")
end

function renderMD(md::Markdown.HorizontalRule)
  Hiccup.Node(:hr)
end


function html(io::IO, md::Markdown.Table)
    withtag(io, :table) do
        for (i, row) in enumerate(md.rows)
            withtag(io, :tr) do
                for c in md.rows[i]
                    withtag(io, i == 1 ? :th : :td) do
                        htmlinline(io, c)
                    end
                end
            end
        end
    end
end

function renderMD(md::Markdown.Table)
  Hiccup.table([
    [Hiccup.tr(Hiccup.Node(i == 1 ? :th : :td, renderMDinline(c))) for c in row]
    for (i, row) in enumerate(md.rows)
  ])
end

# Inline elements

function renderMDinline(content::Vector)
  [renderMDinline(x) for x in content]
end

function renderMDinline(code::Markdown.Code)
  Hiccup.code(code.code) # htmlesc?
end

function renderMDinline(md::Union{Symbol,AbstractString})
  md
    # htmlesc(io, md)
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
    # withtag(io, :a, :href => "#footnote-$(f.id)", :class => "footnote") do
    #     print(io, "[", f.id, "]")
    # end
end

function renderMDinline(link::Markdown.Link)
  Hiccup.Node(:a, renderMDinline(link.text), href = link.url)
end

function renderMDinline(md::Markdown.LaTeX)
  Hiccup.span(md.formula, class = "latex inline")
end

function renderMDinline(io::IO, br::Markdown.LineBreak)
  Hiccup.Node(:br)
end
