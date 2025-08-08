module Report

using ..Lib

export configure!, report, save_asset

mutable struct ReportConfig report_path; asset_path; asset_url_path; first_call end

# if !(@isdefined config)
const config = Ref{Union{ReportConfig, Nothing}}(nothing)
# end

function configure!(; report_path, asset_path, asset_url_path::Union{AbstractString, Nothing}=nothing)
  config[] = ReportConfig(report_path, asset_path, asset_url_path, true)
end

function report(msg::AbstractString; print=true, clear=true)
  indent2to4(text) = begin
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
  space_indent2(str) = join("  " .* split(str, '\n'), "\n")

  cfg = Report.config[]; (cfg === nothing) && error("No report config")

  if cfg.first_call
    cfg.first_call = false
    clear && isfile(cfg.report_path) && rm(cfg.report_path)
  end

  msg = msg |> dedent |> indent2to4 |> replace_h1_with_h3 |> rstrip

  # print && println(space_indent2(msg), "\n")

  mkpath(dirname(cfg.report_path))
  open(cfg.report_path, "a") do io
    write(io, msg * "\n\n")
  end
  nothing
end

safe_name(s::AbstractString) =
  s |> lowercase |>
  x -> replace(x, r"[^a-z0-9]" => "-") |>
  x -> replace(x, r"-+" => "-") |>
  x -> strip(x, ['-'])

function save_asset(name::AbstractString, obj; clear::Bool=true)
  cfg = Report.config[]; (cfg === nothing) && error("No report config")
  fname = "$(safe_name(name)).png"
  path = joinpath(cfg.asset_path, fname); mkpath(dirname(path))

  mod = nameof(parentmodule(typeof(obj)))
  if mod == :Plots
    getfield(parentmodule(typeof(obj)), :savefig)(obj, path)
  elseif mod in (:Makie, :GLMakie, :CairoMakie, :WGLMakie)
    getfield(parentmodule(typeof(obj)), :save)(path, obj)
  elseif obj isa AbstractString
    open(path, "w") do io; write(io, obj) end
  else
    error("Unsupported asset type: $(typeof(obj))")
  end

  url_path = (cfg.asset_url_path === nothing || isempty(cfg.asset_url_path)) ? fname : "$(cfg.asset_url_path)/$fname"
  report("![$name]($url_path)"; clear=clear)
  path
end

end