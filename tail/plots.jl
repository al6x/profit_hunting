show_plots = true

# coolwarm, icefire
function plot_xyc_by(
  tparts, ds; x, y, y2=nothing, color=nothing, by=nothing, detail=nothing,
  xdomain=nothing, ydomain=nothing, scheme="redblue",
  xscale="linear", yscale="linear", pointsize=30, mark=:line, mark2=:line,
  width=1024, height=1024
)
  tparts = ["$tparts x=$x, y=$y"]
  color  !== nothing && push!(tparts, ", color=$color")
  detail !== nothing && push!(tparts, "($detail)")
  y2     !== nothing && push!(tparts, ", dashed=$y2")
  by     !== nothing && push!(tparts, " by=$by")
  ftitle = join(tparts, "")

  xscale_props = xdomain === nothing ? (type=xscale,) : (type=xscale, domain=xdomain)
  yscale_props = ydomain === nothing ? (type=yscale,) : (type=yscale, domain=ydomain)

  color_props = color === nothing ? (;) :
    (; color=(field=color, type=:ordinal, scale=(scheme=scheme, reverse=true)))
  detail_props = detail === nothing ? (;) :
    (; detail=(field=detail, type=:ordinal))
  poinsize_props = mark == :point ? (size=(value=pointsize,),) : (;)

  # y1
  layers = []
  mark_props1 =
    mark == :line             ? (type=:line, clip=true) :
    mark == :line_with_points ? (type=:line, clip=true, point=true) :
    (type=:circle, clip=true,)
  encoding1 = (
    x = (field=x, type=:quantitative, scale=xscale_props),
    y = (field=y, type=:quantitative, scale=yscale_props),
    color_props...,
    detail_props...,
    poinsize_props...
  )
  push!(layers, (mark=mark_props1, encoding=encoding1,))

  if y2 !== nothing
    mark_props2 =
      mark2 == :line ?             (type=:line, clip=true, strokeDash=[4,4]) :
      mark2 == :line_with_points ? (type=:line, clip=true, strokeDash=[4,4], point=true) :
      (type=:point, clip=true, shape=:diamond)
    encoding2 = (;
      encoding1...,
      y = (field=y2, type=:quantitative, scale=yscale_props),
    )
    push!(layers, (mark=mark_props2, encoding=encoding2,))
  end

  # Spec
  columns = 3
  width_prop  = by === nothing ? width  : ceil(Int, width/columns)
  height_prop = by === nothing ? height : ceil(Int, height/columns)
  vspec = by === nothing ?
    (title=ftitle, layer=layers) :
    (
      title=ftitle,
      facet=(field=String(by), type=:ordinal),
      columns,
      spec=(layer=layers, width=width_prop, height=height_prop)
    )

  spec = VegaLite.VLSpec(JSON.parse(JSON.json(vspec)))
  fig = spec(ds)
  show_plots && display(fig)
  save_asset(ftitle, fig)
end