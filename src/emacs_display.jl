
# function BestRepresentation(obj)
#     if hasmethod(show, Tuple{IO,MIME"image/svg+xml",typeof(obj)})
#         show(io, MIME"image/svg+xml"(), obs.result)
#     else
#         show(io, MIME"text/plain"(), obs.result)
#     end
# end

using Plots

struct EMACS_DISPLAY <: AbstractDisplay end

import Base: display
function display(d::EMACS_DISPLAY, p::Plots.Plot)
    # Is this really needed?
    Base.invokelatest(show, stdout, MIME"image/svg+xml"(), p)
end
display(d::EMACS_DISPLAY, obj::CLEAR) = println(stdout, "\n<clear></clear>")
