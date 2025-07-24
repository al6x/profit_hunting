module Report

using ..Lib

export configure!, report

mutable struct ReportConfig report_path; asset_path; asset_url_path; first_call end

# if !(@isdefined config)
const config = Ref{Union{ReportConfig, Nothing}}(nothing)
# end

function configure!(; report_path, asset_path, asset_url_path::Union{AbstractString, Nothing}=nothing)
  config[] = ReportConfig(report_path, asset_path, asset_url_path, true)
end

function report(msg::AbstractString; print=true)
  function indent2to4(text::AbstractString)
    lines = split(text, '\n'; keepempty=true)
    out = String[]
    start_block = true
    for line in lines
      if start_block && startswith(line, "  ")
        push!(out, "  " * line)
      else
        push!(out, line)
        start_block = isempty(line)
      end
    end
    return join(out, '\n')
  end

  replace_h1_with_h3(text) = replace(text, r"(^|\n)# " => s"\1### ")
  # replace_h1_with_h3(text) = replace(text, r"(^|\n)# " => x -> "$(x)### ")
  space_indent2(str) = join("  " .* split(str, '\n'), "\n")

  cfg = Report.config[]; (cfg === nothing) && error("No report config")

  if cfg.first_call
    cfg.first_call = false
    isfile(cfg.report_path) && rm(cfg.report_path)
  end

  msg = msg |> dedent |> indent2to4 |> replace_h1_with_h3 |> rstrip

  # print && println(space_indent2(msg), "\n")

  mkpath(dirname(cfg.report_path))
  open(cfg.report_path, "a") do io
    write(io, msg * "\n\n")
  end
  nothing
end

end