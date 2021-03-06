
include("ConstantSpace.jl")

include("IntervalSpace.jl")
include("PeriodicSpace.jl")


include("Modifier/Modifier.jl")

include("Ultraspherical/Ultraspherical.jl")
include("Fourier/Fourier.jl")
include("Singularities/Singularities.jl")
include("Jacobi/Jacobi.jl")
include("Hermite/Hermite.jl")
include("Mapped/Mapped.jl")



typealias MappedChebyshev Union(Chebyshev,MappedSpace{Chebyshev})
