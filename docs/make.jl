using FunctionObserving
using Documenter

makedocs(;
    modules=[FunctionObserving],
    authors="Daniel Cocks <daniel.cocks@gmail.com> and contributors",
    repo="https://github.com/pengwyn/FunctionObserving.jl/blob/{commit}{path}#L{line}",
    sitename="FunctionObserving.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://pengwyn.github.io/FunctionObserving.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/pengwyn/FunctionObserving.jl",
)
