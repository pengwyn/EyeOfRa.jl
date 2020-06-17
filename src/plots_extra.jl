
function display(d::EMACS_DISPLAY, p::Plots.Plot)
    # TODO: decide which way is best to draw this.
    filename = tempname(ImagesDir()) * ".svg"
    Base.invokelatest(Plots.svg, p, filename)
    println(stdout,"\n<emacs-svg>$filename</emacs-svg>")
end
