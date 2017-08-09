import DocSeeker: baseURL, finddocsURL, readmepath

@test baseURL(finddocsURL("base")) == "https://docs.julialang.org"

@test readmepath("DocSeeker") == abspath(joinpath(@__DIR__, "..", "README.md"))
