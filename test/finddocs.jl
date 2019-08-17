import DocSeeker: baseURL, finddocsURL, readmepath

@testset "finddocs" begin
    @testset "finddocsURL" begin
        @test baseURL(finddocsURL("base")) == "https://docs.julialang.org"
    end

    @testset "readmepath" begin
        @test readmepath("DocSeeker") == abspath(joinpath(@__DIR__, "..", "README.md"))
    end
end
