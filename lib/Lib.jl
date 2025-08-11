module Lib

import Printf

export dedent, configure!, unzip

function dedent(s::AbstractString)
  lines = split(s, '\n')
  non_empty = filter(x -> !isempty(strip(x)), lines)
  isempty(non_empty) && return ""
  min_indent = minimum(length(l) - length(lstrip(l)) for l in non_empty)
  return join([l[min_indent+1:end] for l in lines], "\n")
end

function unzip(rows)
  rows = collect(rows)
  isempty(rows) && error("empty input")
  n = length(rows[1])
  ntuple(j -> getindex.(rows, j), n)
end

mutable struct LibConfig show_round::Int end
const config = Ref{Union{LibConfig, Nothing}}(nothing)

function configure!(; show_round=4)
  config[] = LibConfig(show_round)
end
configure!()

function Base.show(io::IO, f::Float64)
  Printf.@printf(io, "%.*f", config[].show_round, f)
end

end