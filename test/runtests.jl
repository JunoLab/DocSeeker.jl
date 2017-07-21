using DocSeeker
using Base.Test

import DocSeeker: dynamicsearch

function firstN(matches, desired, N = 3)
  binds = map(x -> x[2].name, matches[1:N])
  for d in desired
    if !(d in binds)
      return false
    end
  end
  return true
end

# get rid of `[2]` once dynamicsearch stops returning the score
# @test firstN(dynamicsearch("precompilation")[2], ["compilecache", "__precompile__", "precompile"])
@test firstN(dynamicsearch("sine"), ["sin", "sind", "asin"], 20)

DocSeeker._createdocsdb()
@test isfile(DocSeeker.dbpath)
@test !isempty(DocSeeker.loaddocsdb())

include("finddocs.jl")
