module Lib

import Printf
using Statistics

export dedent, configure!, unzip, flatten, spread, mscore

mscore(x) = begin
  center = mean(x)
  scale = sqrt(π/2)*mean(abs.(x .- center))
  (x .- center) ./ scale
end

spread(nt::NamedTuple) = begin
  n = nothing
  for v in values(nt)
    v isa AbstractArray || continue
    n === nothing && (n = length(v); continue)
    length(v) == n || error("Mismatched lengths among vector fields.")
  end
  n === nothing && return nt  # No composite fields, return as-is
  (; (k => (v isa AbstractArray ? v : fill(v, n)) for (k, v) in pairs(nt))...)
end

dedent(s::AbstractString) = begin
  lines = split(s, '\n')
  non_empty = filter(x -> !isempty(strip(x)), lines)
  isempty(non_empty) && return ""
  min_indent = minimum(length(l) - length(lstrip(l)) for l in non_empty)
  return join([l[min_indent+1:end] for l in lines], "\n")
end

unzip(rows::AbstractVector{T}) where {T<:Union{Tuple,AbstractVector}} = begin
  isempty(rows) && error("empty input")
  N = length(first(rows))
  return ntuple(j -> getindex.(rows, j), N)
end

unzip(rows::Base.Generator) = unzip(collect(rows))

flatten(v::AbstractVector{<:AbstractVector{T}}) where {T} = collect(Iterators.flatten(v))

mutable struct LibConfig show_round::Int end
const config = Ref{Union{LibConfig, Nothing}}(nothing)

function configure!(; show_round=4)
  config[] = LibConfig(show_round)
end
configure!()

# function Base.show(io::IO, f::Float64)
#   Printf.@printf(io, "%.*f", config[].show_round, f)
# end

end