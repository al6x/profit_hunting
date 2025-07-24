module Lib

export dedent

function dedent(s::AbstractString)
  lines = split(s, '\n')
  non_empty = filter(x -> !isempty(strip(x)), lines)
  isempty(non_empty) && return ""
  min_indent = minimum(length(l) - length(lstrip(l)) for l in non_empty)
  return join([l[min_indent+1:end] for l in lines], "\n")
end

end