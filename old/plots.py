import pandas as pd
import numpy as np
from scipy.optimize import minimize
from scipy.stats import norm
import matplotlib.pyplot as plt
import inspect
import math
from matplotlib.lines import Line2D
from lib.helpers import save_asset
import seaborn as sns

show=True

def plot_mmean(title, yname, gname, ylabel, ydomain, clabel, mmeans, scale='linear', ax=None, y2name=None):
  if not isinstance(mmeans, pd.DataFrame): mmeans = pd.DataFrame(mmeans)

  groups = sorted(mmeans[gname].unique())
  cmap = plt.get_cmap('coolwarm')
  colors = cmap(np.linspace(0, 1, len(groups)))

  ax.set_xlabel('Period')
  ax.set_ylabel(ylabel)
  ax.set_title(title, fontsize=10)
  ax.set_xscale('log')
  ax.set_ylim(ydomain[0], ydomain[1])

  if scale == 'log':
    ax.set_yscale('log')

  for i, v in enumerate(groups):
    sub = mmeans[mmeans[gname] == v].sort_values('period')
    x, y = sub['period'], sub[yname]
    ax.scatter(x, y, color=colors[i], s=20, alpha=0.7, lw=0.2, label=f'{v}')
    ax.plot(x, y, linestyle='--', color=colors[i], alpha=0.7, lw=1)
    if y2name:
      ax.plot(x, sub[y2name], color=colors[i], lw=2)

  ax.grid(True, which='both', ls=':')
  ax.legend(title=clabel, fontsize='xx-small', loc='upper right')

def plot_grid(title, axes, ncols=2, figsize=(12, 8)):
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

  if show:
    plt.show()
  save_asset(fig, title)

# def plot_mmeans_by_period_vol_rf(title, df, x, y, color, facet, y2=None, ydomain=None):
#   # Seaborn style
#   sns.set(style="whitegrid")

#   # FacetGrid by period with independent scales
#   g = sns.FacetGrid(df,
#     col=facet,
#     col_wrap=3,
#     height=3,
#     sharex=False,
#     sharey=False,
#     hue=color,
#     palette="coolwarm"
#   )
#   if ydomain is not None:
#     g.set(ylim=ydomain)

#   # Map both scatter and lineplot
#   # g.map_dataframe(sns.lineplot, x=x, y=y, marker="o")
#   g.map_dataframe(sns.lineplot, x=x, y=y, marker="o", linestyle="--")
#   if y2 is not None:
#     g.map_dataframe(sns.lineplot, x=x, y=y2, linestyle="-")

#   # Add a single legend for rfg
#   g.add_legend(title=color)
#   g._legend.set_loc("lower right")
#   g._legend.set_bbox_to_anchor((0.9, 0.05))

#   # Label axes and title
#   # g.set_axis_labels(x, y)
#   g.set(ylabel=None, xlabel=None)
#   g.set_titles("{col_name}")

#   g.fig.suptitle(title)
#   plt.tight_layout()
#   if show:
#     plt.show()
#   save_asset(g.fig, title)

def plot_mmeans_by_period_vol_rf(title, df, x, y, color, facet, y2=None, ydomain=None, show=True, palette="coolwarm"):
  if not isinstance(df, pd.DataFrame): df = pd.DataFrame(df)

  periods = sorted(df[facet].unique())
  ncols, nrows = 3, math.ceil(len(periods)/3)
  fig, axes = plt.subplots(nrows, ncols, figsize=(4*ncols, 3*nrows), squeeze=False)

  if palette == "coolwarm":
    cmap = plt.get_cmap('coolwarm', len(df[color].unique()))
    palette_colors = {v: cmap(i) for i, v in enumerate(sorted(df[color].unique()))}
  elif palette == "icefire":
    palette_vals = sns.color_palette("icefire", n_colors=len(df[color].unique()))
    palette_colors = {v: palette_vals[i] for i, v in enumerate(sorted(df[color].unique()))}
  else:
    raise ValueError(f"Unsupported palette: {palette}")

  for ax, per in zip(axes.flat, periods):
    ax.grid(True, linestyle='--', linewidth=0.5, alpha=0.7)
    sub = df[df[facet] == per]
    for lvl in sorted(df[color].unique()):
      grp = sub[sub[color] == lvl]
      if grp.empty: continue
      ax.plot(grp[x], grp[y], linestyle='--', marker='o', color=palette_colors[lvl], label=lvl, alpha=0.7, markersize=3, linewidth=1)
      if y2 is not None: ax.plot(grp[x], grp[y2], linestyle='-', marker='o', color=palette_colors[lvl], markersize=3, linewidth=2)
    ax.set_title(per); ax.set_xlabel(''); ax.set_ylabel('')
    # ax.set_yscale('log')
    if ydomain: ax.set_ylim(bottom=ydomain[0] if ydomain[0] is not None else ax.get_ylim()[0], top=ydomain[1] if ydomain[1] is not None else ax.get_ylim()[1])

  for ax in axes.flat[len(periods):]: fig.delaxes(ax)  # remove empty plots
  handles, labels = axes.flat[0].get_legend_handles_labels()
  fig.legend(handles, labels, title=color, loc='lower right', bbox_to_anchor=(0.9, 0.05))
  fig.suptitle(title); plt.tight_layout()
  if show: plt.show()
  save_asset(fig, title)