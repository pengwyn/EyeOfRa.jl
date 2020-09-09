

# Something it seems I need - from https://github.com/JuliaLang/julia/issues/32567
import Base: redirect_stdout
function redirect_both(f::Function, stdout_buf, stderr_buf)
    old_stdout = stdout
    old_stderr = stderr

    stdout_rd,stdout_wr = redirect_stdout()
    stderr_rd,stderr_wr = redirect_stderr()

    # Have to jump through hoops to clear the pipes and to not run into blocking
    # issues.
    transfer_stdout = @async begin
        while isopen(stdout_wr)
            write(stdout_buf, read(stdout_rd))
        end
    end
    transfer_stderr = @async begin
        while isopen(stderr_wr)
            write(stderr_buf, read(stderr_rd))
        end
    end
        
    try
        ret = f()

        flush(stdout_wr)
        flush(stderr_wr)
        Libc.flush_cstdio()
        flush(stdout)
        flush(stderr)
        close(stdout_wr)
        close(stderr_wr)
        close(stdout_rd)
        close(stderr_rd)

        wait(transfer_stdout)
        wait(transfer_stderr)

        return ret
    finally
        redirect_stdout(old_stdout)
        redirect_stderr(old_stderr)
    end
end

function PrettyTime(secs, sigfigs=2)
    time = secs*1e6
    
    factors = [1000, 1000, 60, 60, 24, Inf]
    cumfactors = cumprod(factors)
    names = ["μs", "ms", "secs", "mins", "hrs", "days"]
    ind = findfirst(time .< cumfactors)

    out = time
    if ind > 1
        out /= cumfactors[ind-1]
    end
    out = round(out, sigdigits=sigfigs)

    return string(out) * " " * names[ind]
end
