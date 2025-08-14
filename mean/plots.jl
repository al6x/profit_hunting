show_plots = false

function plot_xyc_by(
  title, ds; x, y, y2=nothing, c, by, xdomain=nothing, ydomain=nothing, palette="coolwarm", xscale="linear", yscale="linear",
  pointsize=3
)
  py"""
  show_plots = $(show_plots)
  markersize = $(pointsize)
  title, xdomain, ydomain, palette, xscale, yscale = $(title), $(xdomain), $(ydomain), $(palette), $(xscale), $(yscale)
  by, x, y, y2, color = $(by), $(x), $(y), $(y2), $(c)
  df = $(to_dict(ds))

  ftitle = f"{title} (x={x}, y={y}, c={color}{', dashed=' + y2 if y2 is not None else ''}, by {by})"

  import pandas as pd
  import numpy as np
  import matplotlib.pyplot as plt
  import math
  from lib.helpers import save_asset

  df = pd.DataFrame(df)

  periods = sorted(df[by].unique())
  ncols, nrows = 3, math.ceil(len(periods)/3)
  fig, axes = plt.subplots(nrows, ncols, figsize=(4*ncols, 3*nrows), squeeze=False)

  if palette == "coolwarm":
    cmap = plt.get_cmap('coolwarm', len(df[color].unique()))
    palette_colors = {v: cmap(i) for i, v in enumerate(sorted(df[color].unique()))}
  elif palette == "icefire":
    import seaborn as sns
    palette_vals = sns.color_palette("icefire", n_colors=len(df[color].unique()))
    palette_colors = {v: palette_vals[i] for i, v in enumerate(sorted(df[color].unique()))}
  else:
    raise ValueError(f"Unsupported palette: {palette}")

  for ax, per in zip(axes.flat, periods):
    ax.grid(True, linestyle='--', linewidth=0.5, alpha=0.7)
    sub = df[df[by] == per]
    for lvl in sorted(df[color].unique()):
      grp = sub[sub[color] == lvl]
      if grp.empty: continue
      ax.plot(
        grp[x], grp[y], linestyle='-', marker='o', color=palette_colors[lvl], label=lvl, alpha=0.7,
        markersize=markersize, linewidth=2
      )
      if y2 is not None:
        ax.plot(grp[x], grp[y2], linestyle='--', marker='o', color=palette_colors[lvl],
          markersize=markersize, linewidth=1)
    ax.set_title(per); ax.set_xlabel(''); ax.set_ylabel('')
    if xscale == "log": ax.set_xscale('log')
    if yscale == "log": ax.set_yscale('log')
    if xdomain: ax.set_xlim(
      left=xdomain[0] if xdomain[0] is not None else ax.get_xlim()[0],
      right=xdomain[1] if xdomain[1] is not None else ax.get_xlim()[1]
    )
    if ydomain: ax.set_ylim(
      bottom=ydomain[0] if ydomain[0] is not None else ax.get_ylim()[0],
      top=ydomain[1] if ydomain[1] is not None else ax.get_ylim()[1]
    )

  for ax in axes.flat[len(periods):]: fig.delaxes(ax)  # remove empty plots
  handles, labels = axes.flat[0].get_legend_handles_labels()
  fig.legend(handles, labels, title=color, loc='lower right', bbox_to_anchor=(0.9, 0.05))
  fig.suptitle(ftitle); plt.tight_layout()
  if show_plots: plt.show()
  save_asset(fig, ftitle, clear=False)
  plt.close(fig)
  """
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