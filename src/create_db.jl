using Serialization, Pkg, DocSeeker

db_path(pkg, env) = joinpath(@__DIR__, "..", "db", string(pkg, "-", hash(env), ".db"))

function create_db(pkg, env)
    sympkg = Symbol(pkg)
    db = db_path(pkg, env)
    cd(env) do
        open(db, "w+") do io
            if pkg == "Base"
                serialize(io, DocSeeker.alldocs(Base))
            else
                mod = Main.eval(quote
                    using $sympkg
                    $sympkg
                end)
                serialize(io, DocSeeker.alldocs(mod))
            end
        end
    end
end


pkg, env = ARGS

Pkg.activate(env)
create_db(pkg, env)
