import DocSeeker: baseURL, finddocsURL, readmepath

@test baseURL(finddocsURL("base")) == "https://docs.julialang.org"

@test readmepath("DocSeeker") == joinpath(@__FILE__, "..", "README.md")
