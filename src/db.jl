using SQLite

const sqldbpath = joinpath(@__DIR__, "..", "db", "db.sqlite")

function createDB()
  local db
  if !isfile(sqldbpath)
    db = SQLite.DB(sqldbpath)
    # would actually like to use `CREATE VIRTUAL TABLE DOCS fts5(...)` here, but SQLite.jl's
    # sqlite lib isn#t compiled with support for fts5...
    SQLite.query(db,
      """
      CREATE TABLE DOCS(
        MODULE         TEXT,
        BINDING        TEXT,
        DOCSTRING      TEXT,
        PATH           TEXT,
        LINENUMBER     INT
      )
      """)
  else
    db = SQLite.DB(sqldbpath)
  end

  stmnt = SQLite.Stmt(db,
    """
    INSERT INTO DOCS (MODULE, BINDING, DOCSTRING, PATH, LINENUMBER)
      VALUES (?, ?, ?, ?, ?)
    """)

  for doc in alldocs()
    SQLite.bind!(stmnt, [string(doc.mod), string(doc.name), doc.text, doc.path, doc.line])
    SQLite.execute!(stmnt)
  end
  db
end

function readDB()
  db = SQLite.DB(sqldbpath)
  df = SQLite.query(db, "SELECT * FROM DOCS")
  res = DocObj[]
  for i = 1:size(df, 1)
    m = get(df[i,1], Main)
    n = get(df[i,2], Symbol(""))
    md = Nullable(Markdown.parse(get(df[i,3], "")))
    t = get(df[i,3], "")
    p = get(df[i,4], "")
    l = get(df[i,5], "")
    push!(res, DocObj(n, m, md, t, p, l))
  end
  res
end
