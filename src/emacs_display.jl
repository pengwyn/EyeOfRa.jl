

using Plots

struct EMACS_DISPLAY <: AbstractDisplay end

import Base: display

display(d::EMACS_DISPLAY, obj::CLEAR) = println(stdout, "\n<emacs-clear></emacs-clear>")

# function display(d::EMACS_DISPLAY, p::Plots.Plot)
#     # Is this really needed?
#     Base.invokelatest(show, stdout, MIME"image/svg+xml"(), p)
# end

images_tempdir = nothing
function ImagesDir() 
    global images_tempdir
    if images_tempdir === nothing
        images_tempdir = mktempdir()
    end
    images_tempdir
end


