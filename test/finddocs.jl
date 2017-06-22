import DocSeeker: baseURL, finddocsURL

@test baseURL(finddocsURL("base")) = "https://docs.julialang.org"
