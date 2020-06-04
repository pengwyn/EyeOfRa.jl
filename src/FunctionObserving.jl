module FunctionObserving

export @observe

using Revise
using Crayons, Crayons.Box
using Dates

using MacroTools


##############################
# * Structs
#----------------------------

struct OBSERVATION
    time::Float64
    result
    inferred_type
    stdout::String
    stderr::String
    stacktrace
end
import Base: ==
# ==(a::OBSERVATION, b::OBSERVATION) = (something(a.result) == something(b.result) && a.stdout == b.stdout)
function ==(a::OBSERVATION, b::OBSERVATION)
    prop_set = [:result, :stdout, :stderr, :inferred_ret]
    return all(getproperty(a,prop) == getproperty(b,prop) for prop in prop_set)
end

include("utils.jl")
include("printing.jl")

##############################
# * Observing
#----------------------------

# macro observe(mod, expr)
#     if @capture(expr, func_(args__))
#         :(ObserveFunctionCollector($mod, $func, $(args...)))
#     else
#         error("Doesn't appear to be a function call")
#     end
# end

"""
    @observe func(args... ; kwds...)
    
Use `Revise` to "observe" changes to a functions behaviour. This will track the
return values and the stdout/stderr of the function.
    
Notes:
* This only tracks stdout, stderr output using `redirect_stdxxx`. Many functions
  (e.g. `display`) will not output to the current stdout and so will not be captured.
* "Repeats" are recorded. Two calls repeat, when they have the same output.
* Currently, any change to the function's module will cause the function to be retested.
* This will probably only work on linux at the moment...
"""
macro observe(expr)
    if expr.head != :call
        error("Doesn't appear to be a function call")
    else
        # func = esc(popfirst!(expr.args))
        # args = esc.(expr.args)
        # quote
        #     mod = typeof($func).name.module
        #     ObserveFunctionCollector(mod, $func, $(args...))
        # end
        quote
            ObserveFunctionCollector(:auto, $(esc.(expr.args)...))
        end
    end
end

ObserveFunctionCollector(mod, func, args... ; kwds...) = ObserveFunction(mod, func, args, kwds)

"""
    ObserveFunction(args...; kwds...) = ObserveFunction(stdout, args... ; kwds...)
    
See `@observe` for details.
"""
ObserveFunction(args...; kwds...) = ObserveFunction(stdout, args... ; kwds...)
ObserveFunction(io::IO, mod::Symbol, func, args... ; kwds...) = ObserveFunction(io, (mod == :auto ? typeof(func).name.module : error("Unknown mod symbol $mod")), func, args... ; kwds...)

function ObserveFunction(io::IO, mod, func, args, kwds=[] ; show_diffs=true)
    local last_call = nothing
    local last_success = nothing
    local n = 0
    local repeats = 0

    # @show mod func args kwds
    # error("stop")

    entr([], [mod]) do
        ShowRetest(io)

        ret = TestFunction(func, args, kwds)
        n += 1
        if ret == last_call
            repeats += 1
        else
            repeats = 1
        end
        
        ShowHeader(io, n,repeats, (func,args,kwds))

        if ret.result isa Exception
            ShowError(io, ret)
            ShowObservation(io, last_success, nothing)
            last_call = ret
        else
            ShowObservation(io, ret, last_success)
            last_call = last_success = ret
        end
    end
end

function TestFunction(func, args, kwds)
    local result
    local inferred_type = nothing
    local bt = nothing
    stdout_save = IOBuffer()
    stderr_save = IOBuffer()

    time = @elapsed begin
        try
            inferred_type = Base.return_types(func, map(typeof, args))[]
            result = redirect_both(stdout_save, stderr_save) do
                Base.invokelatest(func, args... ; kwds...)
            end
        catch exc
            exc isa InterruptException && rethrow()        
            result = exc
            bt = stacktrace(catch_backtrace())
            # Base.StackTraces.remove_frames!(bt, :TestFunction)
            ind = findlast(frame -> frame.func == :TestFunction, bt)
            ind = findprev(frame -> occursin("invokelatest", string(frame.func)), bt, ind)
            if ind !== nothing && ind-2 >= 1
                deleteat!(bt, ind-2:lastindex(bt))
            end
        end
    end

    return OBSERVATION(time, result, inferred_type, String(take!(stdout_save)), String(take!(stderr_save)), bt)
end




end # module
