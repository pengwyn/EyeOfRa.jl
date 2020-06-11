
const C_HEAD = Crayon(bold=true, foreground=:blue)
const C_DIFF = YELLOW_FG

function ShowRetest(io)
    println(io, Crayon(foreground=:yellow, negative=true)("Rerunning code..."))
end

function ShowHeader(io, S, (func,args,kwds))
    println(io, "ZCLEARZ")
    run(`clear`)
    C = NEGATIVE

    println(io, C("Command:"), " $func(", join(args, ", "), " ; ", join(kwds, ", "), ")")
    time = Dates.format(now(), dateformat"HH:MM:SS")
    println(io, C("Iteration: $(lpad(S.n,4))"), " - time: $(time)")
    if S.repeats >= 2
        println(io, Crayon(foreground=:green)("Repeated: $(lpad(S.repeats,4))"))
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
    ShowStds(io, obs)
    println(io)
end

ShowObservation(io::IO, obs::Nothing, last_success) = println(io, "No observation!")
function ShowObservation(io::IO, obs, last_success)
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
    if (obs.result isa Exception)
        PrettyResult(io, last_success, nothing)
    else
        PrettyResult(io, obs, last_success)
    end
end

ShowStds(io, obs::Nothing) = nothing
function ShowStds(io, obs)
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


PrettyResult(io::IO, obs::Nothing, last_success) = println(io, "No observation")
function PrettyResult(io::IO, obs, last_success)
    print(io, C_HEAD("Return: "))

    if last_success === nothing || typeof(last_success.result) == typeof(obs.result)
        type_crayon = Crayon(faint=true)
    else
        type_crayon = C_DIFF
    end
    print(io, type_crayon(string(typeof(obs.result))))

    if obs.inferred_type != typeof(obs.result)
        print(io, RED_FG(" <: " * string(obs.inferred_type)))
    end

    println(io)

    show(io, MIME"text/plain"(), obs.result)
    println(io)

    ShowStds(io, obs)
end

