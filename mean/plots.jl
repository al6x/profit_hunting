using VegaLite

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


function plot_by_vol_by_rf(title, ds_vol, ds_rf; ylabel, solid_label, ydomain=nothing, y, y2=nothing, xscale=nothing, yscale=nothing)
  show_plotsv = show_plots
  py"""
  show_plots = $(show_plotsv)
  title, ylabel, solid_label, ydomain, xscale, yscale = $(title), $(ylabel), $(solid_label), $(ydomain), $(xscale), $(yscale)
  y, y2 = $(y), $(y2)
  df_vol, df_rf = $(to_dict(ds_vol)), $(to_dict(ds_rf))

  import pandas as pd
  import numpy as np
  import matplotlib.pyplot as plt
  import math
  from lib.helpers import save_asset

  # try:
  #   plot_mmean
  # except NameError:
  def plot_mmean(title, yname, gname, ylabel, ydomain, clabel, mmeans, xscale, yscale, ax=None, y2name=None):
    if not isinstance(mmeans, pd.DataFrame): mmeans = pd.DataFrame(mmeans)

    groups = sorted(mmeans[gname].unique())
    cmap = plt.get_cmap('coolwarm')
    colors = cmap(np.linspace(0, 1, len(groups)))

    ax.set_xlabel('Period')
    ax.set_ylabel(ylabel)
    ax.set_title(title, fontsize=10)
    if xscale == 'log':
      ax.set_xscale('log')
    if ydomain is not None:
      ax.set_ylim(ydomain[0], ydomain[1])

    if yscale == 'log':
      ax.set_yscale('log')

    for i, v in enumerate(groups):
      sub = mmeans[mmeans[gname] == v].sort_values('period')
      x, y = sub['period'], sub[yname]
      ax.scatter(x, y, color=colors[i], s=20, alpha=0.7, lw=0.2, label=f'{v}')
      ax.plot(x, y, linestyle='-', marker='o', color=colors[i], alpha=0.7, markersize=3, linewidth=2)
      if y2name:
        ax.plot(x, sub[y2name], linestyle='--', marker='o', color=colors[i], markersize=3, linewidth=1)

    ax.grid(True, which='both', ls=':')
    ax.legend(title=clabel, fontsize='xx-small', loc='upper right')

  def plot_grid(title, axes, ncols=2, figsize=(12, 8), show=True):
    n_axes = len(axes)
    nrows = (n_axes + ncols - 1) // ncols  # ceiling division to fit all axes

    fig, grid_axes = plt.subplots(nrows, ncols, figsize=figsize)
    grid_axes = grid_axes.flatten()

    for i, cb in enumerate(axes):
      if i < len(grid_axes):
        cb(grid_axes[i])  # call lambda with grid Axes
      else:
        fig.delaxes(grid_axes[i])  # remove unused axes if any

    fig.suptitle(title)
    # plt.tight_layout(rect=[0, 0, 1, 0.95])
    plt.tight_layout()

    if show: plt.show()
    save_asset(fig, title, clear=False)
    plt.close(fig)

  plot_grid(f"{title} by (T, vol) and (T, rf), (solid - {solid_label})", [
    lambda ax: plot_mmean(
      title=f"{ylabel} by vol",
      ax=ax, ydomain=ydomain, mmeans=df_vol, yname=y, y2name=y2, gname="volg", ylabel=ylabel, xscale=xscale, yscale=yscale,
      clabel='Vol Group',
    ),
    lambda ax: plot_mmean(
      title=f"{ylabel} by RF",
      ax=ax, ydomain=ydomain, mmeans=df_rf, yname=y, y2name=y2, gname="rfg", ylabel=ylabel, xscale=xscale, yscale=yscale,
      clabel='RF Group'
    )
  ], show=show_plots)
  """
end