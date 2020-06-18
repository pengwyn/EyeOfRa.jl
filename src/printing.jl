
const C_HEAD = Crayon(bold=true, foreground=:blue)
const C_DIFF = YELLOW_FG

function ShowRetest()
    println(Crayon(foreground=:yellow, negative=true)("Rerunning code..."))
end

function ShowHeader(S, (func,args,kwds))
    display(CLEAR())
    # println("ZCLEARZ")
    # run(`clear`)
    C = NEGATIVE

    println(C("Command:"), " $func(", join(args, ", "), " ; ", join(kwds, ", "), ")")
    time = Dates.format(now(), dateformat"HH:MM:SS")
    println(C("Iteration: $(lpad(S.n,4))"), " - time: $(time)")
    if S.repeats >= 2
        println(Crayon(foreground=:green)("Repeated: $(lpad(S.repeats,4))"))
    else
        println()
    end
end


function ShowError(obs::OBSERVATION)
    @assert obs.result isa Exception
    bts = Base.process_backtrace(obs.stacktrace)
    rows = map(bts) do bt
        frame = bt[1]
        fileinfo = basename(string(frame.file)) * ":$(frame.line)" * (frame.inlined ? " [inlined]" : "")
        funcinfo = sprint(Base.StackTraces.show_spec_linfo, frame)

        out = [fileinfo, funcinfo]
    end

    if isempty(rows)
        rows = []
    else
        tab = hcat(rows...) |> permutedims

        # TODO: Turn this into a generic table print. Or find where others do this.
        total_max = 80
        max_sizes = [40 40]
        pad_funcs = [lpad rpad]
        col_sizes = maximum(length.(tab), dims=1)
        col_sizes = min.(col_sizes, max_sizes)
        if sum(col_sizes) < total_max
            col_sizes[end] += total_max - sum(col_sizes)
        end

        Truncate(s,n,pad) = length(s) > n ? s[1:nextind(s,n-1)] : pad(s,n)
        tab = Truncate.(tab, col_sizes, pad_funcs)

        rows = join.(eachrow(tab), " | ")
    end
    println(RED_BG("Exception: ", sprint(showerror, obs.result)))
    println(YELLOW_FG(join(rows,"\n")))
    println()
    ShowStds(obs)
    println()
end

ShowObservation(obs::Nothing, last_success) = println("No observation!")
function ShowObservation(obs, last_success)
    # println()
    print(C_HEAD("Duration: "), PrettyTime(obs.time))
    if last_success !== nothing
        Δt = obs.time - last_success.time
        if Δt > 0
            print(RED_FG(" + ", PrettyTime(abs(Δt))))
        else
            print(GREEN_FG(" - ", PrettyTime(abs(Δt))))
        end
    end
    println()
    if (obs.result isa Exception)
        PrettyResult(last_success, nothing)
    else
        PrettyResult(obs, last_success)
    end
end

ShowStds(obs::Nothing) = nothing
function ShowStds(obs)
    if !isempty(obs.stdout)
        println()
        println(GREEN_FG("With stdout output: "))
        println(obs.stdout)
    end
    if !isempty(obs.stderr)
        println()
        println(RED_FG("With stderr output: "))
        println(obs.stderr)
    end
end


PrettyResult(obs::Nothing, last_success) = println("No observation")
function PrettyResult(obs, last_success)
    print(C_HEAD("Return: "))

    if last_success === nothing || typeof(last_success.result) == typeof(obs.result)
        type_crayon = Crayon(faint=true)
    else
        type_crayon = C_DIFF
    end
    print(type_crayon(string(typeof(obs.result))))

    if obs.inferred_type != typeof(obs.result)
        print(RED_FG(" <: " * string(obs.inferred_type)))
    end

    println()

    try
        display(obs.result)
    catch exc
        println(RED_BG("Got error while trying to display result."))
        showerror(stderr, exc)
    end
    println()

    ShowStds(obs)
end


# This is a setup to allow it to be overridden in other displays.
struct CLEAR end

import Base: show, display
show(obj::CLEAR) = println(string(obj))

display(d::AbstractDisplay, ::CLEAR) = run(`clear`)


