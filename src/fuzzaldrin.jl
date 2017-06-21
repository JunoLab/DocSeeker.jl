# https://github.com/atom/fuzzaldrin/blob/master/src/scorer.coffee
function fuzzaldrin_score(needle::String, haystack::String)
  needle == haystack && return 1.0

  totalCharacterScore = 0.0
  needleLength = length(needle)
  haystackLength = length(haystack)

  for (i, c) in enumerate(needle)
    lowerCaseIndex = searchindex(haystack, lowercase(c))
    upperCaseIndex = searchindex(haystack, uppercase(c))
    minIndex = min(lowerCaseIndex, upperCaseIndex)
    minIndex == 0 && (minIndex = max(lowerCaseIndex, upperCaseIndex))

    indexInString = minIndex

    indexInString == 0 && return 0.0

    characterScore = 0.1

    haystack[chr2ind(haystack, minIndex)] == c && (characterScore += 0.1)

    if indexInString == 1
      characterScore += 0.8
    elseif haystack[prevind(haystack, chr2ind(haystack, minIndex))] in ['_', '-', ' ']
      characterScore += 0.7
    end

    haystack = haystack[nextind(haystack, chr2ind(haystack, indexInString)):end]

    totalCharacterScore += characterScore
  end

  queryScore = totalCharacterScore/haystackLength
  return (queryScore*(needleLength/haystackLength) + queryScore)/2
end
