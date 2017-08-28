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

@test firstN(dynamicsearch("sine"), ["sin", "sind", "asin"], 20)

@test firstN(dynamicsearch("regular expression"), ["match", "eachmatch", "search"], 20)

@test dynamicsearch("Real")[1][2].name == "Real"
@test length(dynamicsearch("Real")[1][2].text) > 0

let downloadsearch = dynamicsearch("download")
  dfound = 0
  for d in downloadsearch
    if d[2].name == "download" && d[2].mod == "Base"
      dfound += 1
    end
  end
  @test dfound == 1
end

@test dynamicsearch("regex")[1][2].name == "Regex"

DocSeeker._createdocsdb()
@test isfile(DocSeeker.dbpath)
@test !isempty(DocSeeker.loaddocsdb())

include("finddocs.jl")
