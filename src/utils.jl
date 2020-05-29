

# Something it seems I need - from https://github.com/JuliaLang/julia/issues/32567
import Base: redirect_stdout
function redirect_both(f::Function, stdout_buf, stderr_buf)
    old_stdout = stdout
    old_stderr = stderr
    try
        stdout_rd,stdout_wr = redirect_stdout()
        stderr_rd,stderr_wr = redirect_stderr()

        ret = f()
        # This is ridiculous - readavailable will block without any output and
        # there seems to be no way to tell whether there is any output from the
        # pipes. Is it hidden in libuv somewhere?
        print(stdout, "\0")
        print(stderr, "\0")
        flush(stdout_wr)
        flush(stderr_wr)
        Libc.flush_cstdio()
        flush(stdout)
        flush(stderr)
        close(stdout_wr)
        close(stderr_wr)

        # # Throw away the extra null added.
        write(stdout_buf, readavailable(stdout_rd)[begin:end-1])
        write(stderr_buf, readavailable(stderr_rd)[begin:end-1])

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
