
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

# Report -------------------------------------------------------------------------------------------
# mutable struct ReportConfig report_path; asset_path; asset_url_path; first_call end

# if !isdefined(Main, :report_config)
#   const report_config = Ref{Union{ReportConfig, Nothing}}(nothing)
# end

# configure_report!(; report_path, asset_path, asset_url_path::Union{AbstractString, Nothing}=nothing) = begin
#   report_config[] = ReportConfig(report_path, asset_path, asset_url_path, true)
# end

# report(msg::AbstractString; print_=true) = begin
#   turn_space_indent2_into4(text) = replace(text, r"\n  " => "\n    ")
#   replace_h1_with_h3(text) = replace(text, r"(^|\n)# " => x -> "$(x.match)### ")
#   space_indent2(str) = join("  " .* split(str, '\n'), "\n")

#   cfg = report_config[]; (cfg === nothing) && error("No report config")

#   if cfg.first_call
#     cfg.first_call = false
#     isfile(cfg.report_path) && rm(cfg.report_path)
#   end

#   msg = msg |> dedent |> turn_space_indent2_into4 |> replace_h1_with_h3 |> rstrip

#   print_ && println(space_indent2(msg), "\n")

#   mkpath(dirname(cfg.report_path))
#   open(cfg.report_path, "a") do io
#     write(io, msg * "\n\n")
#   end
#   nothing
# end