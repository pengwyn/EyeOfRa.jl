
const C_HEAD = Crayon(bold=true, foreground=:blue)
const C_DIFF = YELLOW_FG

function ShowHeader(io, n, repeats, (func,args,kwds))
    run(`clear`)
    C = NEGATIVE

    println(io, C("Command:"), " $func(", join(args, ", "), " ; ", join(kwds, ", "), ")")
    time = Dates.format(now(), dateformat"HH:MM:SS")
    println(io, C("Iteration: $(lpad(n,4))"), " - time: $(time)")
    if repeats >= 2
        println(io, Crayon(foreground=:green)("Repeated: $(lpad(repeats,4))"))
    else
        println(io)
    end
end


function ShowError(io::IO, obs::OBSERVATION)
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

        # FIXME: Need to handle unicode here properly
        Truncate(s,n,pad) = length(s) > n ? s[1:n] : pad(s,n)
        tab = Truncate.(tab, col_sizes, pad_funcs)

        rows = join.(eachrow(tab), " | ")
    end
    println(io, RED_BG("Exception: ", sprint(showerror, obs.result)))
    println(io, YELLOW_FG(join(rows,"\n")))
    println(io)
    println(io)
    println(io, NEGATIVE("Previous success:"))
end

ShowObservation(io::IO, obs::Nothing, last_success) = println(io, "No observation")

function ShowObservation(io::IO, obs::OBSERVATION, last_success)
    # println(io)
    print(io, C_HEAD("Duration: "), PrettyTime(obs.time))
    if last_success !== nothing
        Δt = obs.time - last_success.time
        if Δt > 0
            print(io, RED_FG(" + ", PrettyTime(abs(Δt))))
        else
            print(io, GREEN_FG(" - ", PrettyTime(abs(Δt))))
        end
    end
    println(io)
    PrettyResult(io, obs.result, last_success)
    if !isempty(obs.stdout)
        println(io)
        println(io, GREEN_FG("With stdout output: "))
        println(obs.stdout)
    end
    if !isempty(obs.stderr)
        println(io)
        println(io, RED_FG("With stderr output: "))
        println(obs.stderr)
    end
end


function PrettyResult(io::IO, out::Exception, last_call)
    error("Shouldn't get here anymore")
    println(io, Crayon(foreground=:red)("Code errored: ", string(out)))
end

function PrettyResult(io::IO, out::Some, last_success)
    thing = something(out)

    print(io, C_HEAD("Return: "))
    if last_success === nothing || typeof(something(last_success.result)) == typeof(thing)
        println(io, Crayon(faint=true)(string(typeof(thing))))
    else
        println(io, C_DIFF(string(typeof(thing))))
    end
    show(io, MIME"text/plain"(), thing)
    println(io)
end
