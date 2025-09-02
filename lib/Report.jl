module Report

using ..Lib

export configure!, report, report_code, save_asset, clear

mutable struct ReportConfig report_path; asset_path; asset_url_path; first_call end

const config_ = Ref{Union{ReportConfig, Nothing}}(nothing)

configure!(; report_path, asset_path, asset_url_path::Union{AbstractString, Nothing}=nothing) = begin
  config_[] = ReportConfig(report_path, asset_path, asset_url_path, true)
end

clear() = isfile(config().report_path) && rm(config().report_path)

report_code(code::AbstractString; lang=nothing, args...) = begin
  lang_s = lang === nothing ? "" : " $lang"
  report("```$lang_s\n$code\n```"; args...)
end

config() = begin
  (Report.config_[] === nothing) && error("No report config")
  Report.config_[]
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

  if config().first_call
    config().first_call = false
    clear && Report.clear()
  end

  msg = msg |> dedent |> indent2to4 |> replace_h1_with_h3 |> rstrip

  print && println(space_indent2(msg), "\n")

  mkpath(dirname(config().report_path))
  open(config().report_path, "a") do io
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
  fname = "$(safe_name(name)).png"
  path = joinpath(config().asset_path, fname); mkpath(dirname(path))

  mod = nameof(parentmodule(typeof(obj)))
  if mod == :Plots
    getfield(parentmodule(typeof(obj)), :savefig)(obj, path)
  elseif mod == :VegaLite
    getfield(parentmodule(typeof(obj)), :save)(path, obj)
  elseif mod in (:Makie, :GLMakie, :CairoMakie, :WGLMakie)
    getfield(parentmodule(typeof(obj)), :save)(path, obj)
  elseif obj isa AbstractString
    open(path, "w") do io; write(io, obj) end
  else
    error("Unsupported asset type: $(typeof(obj))")
  end

  url_path = (config().asset_url_path === nothing || isempty(config().asset_url_path)) ?
    fname : "$(config().asset_url_path)/$fname"
  report(name; clear=clear)
  report("![$name]($url_path)"; clear=clear)
  path
end

end