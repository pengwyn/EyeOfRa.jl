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


function CaptureStdout(func)
    mktemp() do path,io
        redirect_stdout(func, io)
        close(io)
        read(path, String)
    end
end

using Plots
done = false
@testset "Emacs images" begin
    pushdisplay(EyeOfRa.EMACS_DISPLAY())
    
    try
        output = CaptureStdout() do
            display(EyeOfRa.CLEAR())
        end
        @test occursin("<emacs-clear></emacs-clear>", output)

        output = CaptureStdout() do
            display(plot(1:10))
        end
        @test occursin(r"<emacs-svg>.*</emacs-svg>", output)
    finally
        popdisplay(EyeOfRa.EMACS_DISPLAY())
    end
end
