using SQLite

function createDB()
  local db
  dbpath = joinpath(@__DIR__, "..", "db", "db.sqlite")

  if !isfile(dbpath)
    db = SQLite.DB(dbpath)
    # would actually like to use CREATE VIRTUAL TABLE DOCS fts5(...) here, but SQLite.jl's
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
    db = SQLite.DB(dbpath)
  end

  stmnt = SQLite.Stmt(db,
    """
    INSERT INTO DOCS (MODULE, BINDING, DOCSTRING, PATH, LINENUMBER)
      VALUES (?, ?, ?, ?, ?)
    """)

  for doc in alldocs()
    binding = doc.data[:binding]
    SQLite.bind!(stmnt, [string(binding.mod), string(binding.var), join(doc.text, ' '), doc.data[:path], doc.data[:linenumber]])
    SQLite.execute!(stmnt)
  end
  db
end
