using EyeOfRa
using Test
using Revise: entr, watched_files
using Plots

@testset "All tests" begin
    function LongTest(n)
        @show rand(n)
    end

    # The below comments are what I would like to have for a test with a timeout...
    # however that version ends up blocking and defeats the point. I don't
    # understand what is going on.

    # @testset "Redirect tests" begin
    #     # Test for blocking - need to implement a dodgy timeout here.
    #     ch = Channel()
    #     @async begin
    #         EyeOfRa.TestFunction(LongTest, (), ())
    #         put!(ch, :success)
    #     end
    #     @async begin
    #         sleep(5)
    #         put!(ch, :failure)
    #     end
    #     @test take!(ch) == :success
    # end
    @testset "Redirect tests" begin
        @test_nowarn EyeOfRa.TestFunction(LongTest, (2000,), ())
        @test_nowarn EyeOfRa.TestFunction(LongTest, (4000,), ())
    end


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

    @testset "TestFunction" begin
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

    @testset "Revise interaction" begin
        # This is for an independent check on Revise upgrades, so that they don't
        # break compatibility. It is not a direct check of this package's code.
        mktempdir() do dir
            filename = joinpath(dir, "EyeOfRaTesting.jl")
            write(filename, """
module EyeOfRaTesting
end
""")

            pushfirst!(LOAD_PATH, dir)
            @eval using EyeOfRaTesting
            popfirst!(LOAD_PATH)

            ch = Channel{Symbol}(2)

            task = @async entr([], [EyeOfRaTesting], pause=0) do
                if !isdefined(EyeOfRaTesting, :testfunc)
                    push!(ch, :before)
                else
                    @assert EyeOfRaTesting.testfunc(2) == 2
                    push!(ch, :after)
                    throw(InterruptException())
                end
            end

            @test take!(ch) == :before

            write(filename, """
module EyeOfRaTesting
    testfunc(x) = x
end
""")
            # Wait a couple of seconds
            for i = 1:5
                sleep(0.2)
                istaskdone(task) && break
            end
            @test istaskdone(task)
            # InterruptExcpetion is not eaten by entr in the inner function.
            # Need to check this from the CompositeException object.
            istaskfailed(task) && task.exception.exceptions[].task.exception != InterruptException() && throw(TaskFailedException(task))
            if istaskdone(task) && !istaskfailed(task)
                @test take!(ch) == :after
            end
        end
    end


    function CaptureStdout(func)
        mktemp() do path,io
            redirect_stdout(func, io)
            close(io)
            read(path, String)
        end
    end

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
end
