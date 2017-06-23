using DocSeeker
using Base.Test

import DocSeeker: dynamicsearch

function firstN(matches, desired, N = 3)
  binds = map(x -> x.name, matches[1:N])
  for i = 1:N
    if !(binds[i] in desired)
      return false
    end
  end
  return true
end

# get rid of `[2]` once dynamicsearch stops returning the score
@test firstN(dynamicsearch("precompilation")[2], ["compilecache", "__precompile__", "precompile"])
@test firstN(dynamicsearch("sin")[2], ["sin", "sind", "asin"])

DocSeeker._createdocsdb()
@test isfile(DocSeeker.dbpath)
@test !isempty(DocSeeker.loaddocsdb())

include("finddocs.jl")
