
using Serialization, Dates, PyCall, DataFrames, ..Lib

begin
  path = abspath(joinpath(@__DIR__, ".."))
  py"""
  import sys
  sys.path.insert(0, $path)
  """
end

function cached(get::Function, id::AbstractString)
  date_s = Dates.format(Dates.now(), dateformat"yyyy-mm-dd")
  path = "./tmp/cache/$(id)-$(date_s).jls"

  if isfile(path)
    @info "cache loading" id
    return deserialize(path)
  end

  @info "cache calculating" id
  result = get()
  mkpath(dirname(path))
  serialize(path, result)
  result
end

function to_dict(ds::DataFrame) Dict(string(c) => ds[!, c] for c in names(ds)) end