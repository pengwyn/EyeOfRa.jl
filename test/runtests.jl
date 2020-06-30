using EyeOfRa
using Test

function BasicSuccess(x)
    println("one")
    println(stderr, "two")
    x * 2
end
function BasicFailure(x)
    error("Failed")
end
function BasicInference()
    if rand(Bool)
        1
    else
        1.0
    end
end

@testset "EyeOfRa.jl" begin
    result = EyeOfRa.TestFunction(BasicSuccess, (2,), ())
    @test result.result == 4
    @test result.stdout == "one\n"
    @test result.stderr == "two\n"

    result = EyeOfRa.TestFunction(BasicFailure, (2,), ())
    @test result.result isa Exception

    result = EyeOfRa.TestFunction(BasicInference, (), ())
    @test result.result == 1
    @test result.inferred_type == Union{Float64,Int}
end

# TODO: Fix up these checks
# using Plots
# PlotTest() = plot(1:10)
    
# using Distributed
# task_list = []
# @testset "Emacs images" begin
#     pushdisplay(EyeOfRa.EMACS_DISPLAY())
#     old_stdout = stdout
#     rd,wr = redirect_stdout()

#     # Fallback abort as stdout redirects are annoying
#     @async begin
#         sleep(1)
#         println(stderr,"Here")
#         throwto.(task_list, ErrorException("Blocking somewhere!"))
#     end

#     try
#         push!(task_list, @async begin
#         display(EyeOfRa.CLEAR())
#         readline(rd)
#         readline(rd)
#         @test readline(rd) == "<emacs-clear></emacs-clear>"
#               end)
#         wait.(task_list)
#     finally
#         popdisplay(EyeOfRa.EMACS_DISPLAY())
#         redirect_stdout(old_stdout)
#     end
# end
