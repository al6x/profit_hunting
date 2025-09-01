import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(__file__, '..', '..')))
import pandas as pd
import numpy as np
from scipy.optimize import minimize
from lib.helpers import configure_report, report, cached
from hist_data.data import load_with_bankrupts, adjust_data_mmean
from scipy.stats import norm
from scipy.optimize import minimize, root_scalar, minimize_scalar
import matplotlib.pyplot as plt
import inspect
import math
import plots
from lib.fit import prune_params, fit_multi_init

np.random.seed(1)

configure_report(report_path="mean/readme.md", asset_path="mean/readme", asset_url_path='readme')

doc_before = r"""
Stock Mean Return E[R] from Historical Data.

Run `python mean/run.py`.

Data has both comission and omission biases.
Problems skewed and heavy tailed.

add top image
"""

doc_after = """
  Daily prices for 250 stocks all starting from 1973 till 2025, stats aggregated with moving window with step 30d, so
  larger periods have overlapping. Dividends ignored. Data has survivorship bias, no bankrupts.

  Data adjusted by adding bankrupts. The **annual bankruptsy probability** conditional on company volatility with total
  annual rate P(b|T=365) = 0.5% to drop to x0.1.

  Full data description [data](/hist_data/readme.md).
"""

def norm_mean(mmean, period):
  return np.log(mmean)*(365/period)

def denorm_mean(nmmean, period):
  return np.exp(nmmean*(period/365))

def target_mmeans(df):
  def empir_mmean_for_target(lrs):
    return np.mean(np.exp(lrs))

  # Estimating means by vol and rf quantiles
  # Leaving only 1 and 5 rf quantiles, because other are messed and distort fitting.
  df15 = df[df['rfg'].isin([1, 5])].copy()
  volg_medians = df15.groupby('volg')['vol'].median()
  rfg_medians  = df15.groupby('rfg')['lr_rf'].median()
  mmeans15 = (df15.groupby(['period_d', 'volg', 'rfg'])
    .apply(lambda g: pd.Series({
      'mmean': empir_mmean_for_target(g['lr_t2']),
      'vol':   volg_medians[g.name[1]], # g.name[1] = volg
      'lr_rf': rfg_medians[g.name[2]], # g.name[2] = rfg
    }), include_groups=False)
    .reset_index())

  # But making its total mean same as all 1..5 quantiles, to avoid biasing.
  mmeans_p = (df.groupby(['period_d', 'volg'])
    .apply(lambda g: empir_mmean_for_target(g['lr_t2']), include_groups=False)
    .to_dict())

  # Adjust mmean per period so mean(mmeans15['period_d']^k - mean(mmeans_p['period_d'])) = 0
  for (period, volg), g in mmeans15.groupby(['period_d', 'volg']):
    target_mmean = mmeans_p[(period, volg)]
    k = minimize_scalar(
      lambda K: np.mean((g['mmean'] ** K - target_mmean)**2),
      bounds=(0.1, 10), method='bounded'
    ).x
    idx = (mmeans15['period_d'] == period) & (mmeans15['volg'] == volg)
    mmeans15.loc[idx, 'mmean'] = mmeans15.loc[idx, 'mmean'] ** k
  return mmeans15

def estimate_mean(df):
  init = [-0.0060, 0.1550, 0.2082, -0.1519, -0.0129, 2.3053, -2.2733, -0.4042, 1.2522, -0.5670, 0.0324] #loss=0.8687 reg=0.0074

  def nmmean_(period, vol, lr_rf, P):
    pn, lr, nv = period/365, lr_rf, vol/0.015
    a = P[0] + P[1]*nv + P[2]/10*pn + P[3]/10*nv*pn + P[4]*nv*np.log(period)
    b = P[5] + P[6]*nv + P[7]*pn + P[8]*nv*pn**0.5 + P[9]/nv

    # Model should be linear in lr_rf to avoid overfitting
    return a + b*lr

  def mmean_(period, vol, lr_rf, P):
    return denorm_mean(nmmean_(period, vol, lr_rf, P), period)

  target = target_mmeans(df)
  target['nmmean'] = norm_mean(target['mmean'], target['period_d'])

  def reg(params):
    return 0.01*np.mean(np.abs(params)**0.25)

  def loss(params):
    # Normal Mean has better convergence and seems to be better fit
    errors = nmmean_(target['period_d'], target['vol'], target['lr_rf'], params) - target['nmmean']
    errors /= target['nmmean']

    # errors = mmean_(target['period_d'], target['vol'], target['lr_rf'], params) - target['mmean']
    # errors /= target['mmean']
    return 100*np.mean(errors**2) + reg(params)

  def fit(loss, init):
    return minimize(loss, x0=init, method='L-BFGS-B')
    # return minimize(loss, x0=init, method='Powell')

  # prune_params(loss=loss, fit=fit, init=init, min_params=4)
  # Best 4-param model loss=1.3821, kept=(1, 2, 3, 4)
  # Best 5-param model loss=1.1764, kept=(0, 1, 2, 3, 4)
  # Best 6-param model loss=1.1718, kept=(0, 1, 2, 3, 4, 5)

  # inits = inits = []
  # P = tuple(fit_multi_init(loss, inits, fit))

  P = tuple(fit(loss, init).x)
  # P = cached('lmmean', lambda: tuple(fit(loss, init).x))
  msg = f"Found params=[{', '.join(f'{x:.4f}' for x in P)}], loss={loss(P):.4f} reg={reg(P):.4f}"
  report(msg); print(msg)

  return lambda period, vol, lr_rf: mmean_(period, vol, lr_rf, P)

def assign_rf_quantiles(df):
  x = df['lr_rf'].values
  ranks = np.argsort(np.argsort(x))
  q = (ranks + 1) / len(x)
  df['rf_q'] = q
  df['rf_dc'] = np.minimum((q * 10).astype(int) + 1, 10)
  df['rfg'] = np.minimum((q * 5).astype(int) + 1, 5)

def empir_mmean(lrs):
  # lrs = lrs[lrs <= lrs.quantile(0.99)] # Data biased, forcefully underestimating it
  return np.mean(np.exp(lrs))

def mmeans_by_vol_rf(df, model=None):
  volg_medians = df.groupby('volg')['vol'].median()
  rfg_medians  = df.groupby('rfg')['lr_rf'].median()

  r = (df.groupby(['period_d', 'volg', 'rfg'])
    .apply(lambda g: pd.Series({
      'mmean': empir_mmean(g['lr_t2']),
      'emmean': model(g.name[0], g['vol'], g['lr_rf']).mean() if model else [-1],
      'vol': volg_medians[g.name[1]],   # g.name[1] = volg
      'lr_rf': rfg_medians[g.name[2]],  # g.name[2] = rfg
    }), include_groups=False)
    .reset_index())
  r['nmmean'] = norm_mean(r['mmean'], r['period_d'])
  r['enmmean'] = norm_mean(r['emmean'], r['period_d']) if model else None
  return r

def mmeans_by_vol(df, model=None):
  lr_rf_median  = df['lr_rf'].median()

  r = (df.groupby(['period_d', 'vol_dc'])
    .apply(lambda g: pd.Series({
      'mmean': empir_mmean(g['lr_t2']),
      'emmean': model(g.name[0], g['vol'], g['lr_rf']).mean() if model else None,
      'vol': g['vol'].median(),
      'lr_rf': lr_rf_median,
    }), include_groups=False)
    .reset_index())
  r['nmmean'] = norm_mean(r['mmean'], r['period_d'])
  r['enmmean'] = norm_mean(r['emmean'], r['period_d']) if model else None
  return r

def mmeans_by_rf(df, model=None):
  vol_median = df['vol'].median()
  r = (df.groupby(['period_d', 'rfg'])
    .apply(lambda g: pd.Series({
      'mmean': empir_mmean(g['lr_t2']),
      'emmean': model(g.name[0], g['vol'], g['lr_rf']).mean() if model else [-1],
      'vol': vol_median,
      'lr_rf': g['lr_rf'].median(),
    }), include_groups=False)
    .reset_index())
  r['nmmean'] = norm_mean(r['mmean'], r['period_d'])
  r['enmmean'] = norm_mean(r['emmean'], r['period_d']) if model else None
  return r

def c_adjust_data_mmean(df, lr_t2_orig):
  df_orig = df.copy()
  df_orig['lr_t2'] = lr_t2_orig

  mmeans_vol_orig = mmeans_by_vol(df_orig)
  mmeans_rf_orig  = mmeans_by_rf(df_orig)

  # Comparing adjusted to original
  mmeans_vol = mmeans_by_vol(df)
  mmeans_vol['mmean_orig']  = mmeans_vol_orig['mmean']
  mmeans_vol['nmmean_orig'] = mmeans_vol_orig['nmmean']

  mmeans_rf  = mmeans_by_rf(df)
  mmeans_rf['mmean_orig']  = mmeans_rf_orig['mmean']
  mmeans_rf['nmmean_orig'] = mmeans_rf_orig['nmmean']

  ydomain = (1, 1.8)
  plots.plot_grid("Adjusted Mean E[R] by (T, vol) and (T, rf), (solied line - adjusted)", [
    lambda ax: plots.plot_mmean(
      title="Mean E[R] by vol",
      ax=ax, ydomain=ydomain, mmeans=mmeans_vol, yname='mmean_orig', y2name='mmean', gname='vol_dc', ylabel='E[R]', clabel='Vol Group',
    ),
    lambda ax: plots.plot_mmean(
      title="Mean E[R] by RF",
      ax=ax, ydomain=ydomain, mmeans=mmeans_rf, yname='mmean_orig', y2name='mmean', gname='rfg', ylabel='E[R]', clabel='RF Group'
    ),
  ])

  nydomain = (0, 0.3)
  plots.plot_grid("Adjusted Norm Mean (365/period)log(E[R]) by (T, vol) and (T, rf), (solied line - adjusted)", [
    lambda ax: plots.plot_mmean(
      title="Norm Mean (365/period)log(E[R]) by vol",
      ax=ax, ydomain=nydomain, mmeans=mmeans_vol, yname='nmmean_orig', y2name='nmmean', gname='vol_dc', ylabel='(365/period)log(E[R])', clabel='Vol DC'
    ),
    lambda ax: plots.plot_mmean(
      title="Norm Mean (365/period)log(E[R]) by RF",
      ax=ax, ydomain=nydomain, mmeans=mmeans_rf, yname='nmmean_orig', y2name='nmmean', gname='rfg', ylabel='(365/period)log(E[R])', clabel='RF Group'
    )
  ])

def prepare_data():
  df = cached('mean-df', load_with_bankrupts)
  lr_t2_orig = df['lr_t2'].copy()
  adjust_data_mmean(df)

  df['lr_rf'] = df['lr_rf_1y_t']
  assign_rf_quantiles(df)
  df['volg'] = (df['vol_dc'] + 1) // 2

  # df = df.sample(frac=0.1)
  # df = df[(df['rfg'].isin([1, 5])) & (df['volg'].isin([1, 5])) & (df['period_d'].isin([30, 365, 1095]))]
  # df = df[(df['rfg'].isin([1, 5])) & (df['volg'].isin([1, 5]))]
  return df, lr_t2_orig

def c_estimate_mmean(df, mmean_):
  mmeans_vol_rf, mmeans_vol, mmeans_rf = mmeans_by_vol_rf(df, mmean_), mmeans_by_vol(df, mmean_), mmeans_by_rf(df, mmean_)

  plots.plot_mmeans_by_period_vol_rf(
    "Mean E[R] by (T, rf, vol), x - rf quantile",
    mmeans_vol_rf, x='rfg', y='mmean', y2='emmean', color='volg', facet='period_d', ydomain=(1, None)
  )

  plots.plot_mmeans_by_period_vol_rf(
    "Norm Mean (365/period)log(E[R]) by (T, rf, vol), x - rf quantile",
    mmeans_vol_rf, x='rfg', y='nmmean', y2='enmmean', color='volg', facet='period_d', ydomain=(0, 0.3)
  )

  ydomain = (1, 1.5)
  plots.plot_grid("Mean E[R] by (T, vol) and (T, rf)", [
    lambda ax: plots.plot_mmean(
      title="Mean E[R] by vol",
      ax=ax, ydomain=ydomain, mmeans=mmeans_vol, yname='mmean', y2name='emmean', gname='vol_dc', ylabel='E[R]', clabel='Vol Group',
    ),
    lambda ax: plots.plot_mmean(
      title="Mean E[R] by RF",
      ax=ax, ydomain=ydomain, mmeans=mmeans_rf, yname='mmean', y2name='emmean', gname='rfg', ylabel='E[R]', clabel='RF Group'
    ),
  ])

  nydomain = (0, 0.25)
  plots.plot_grid("Norm Mean (365/period)log(E[R]) by (T, vol) and (T, rf)", [
    lambda ax: plots.plot_mmean(
      title="Norm Mean (365/period)log(E[R]) by vol",
      ax=ax, ydomain=nydomain, mmeans=mmeans_vol, yname='nmmean', y2name='enmmean', gname='vol_dc', ylabel='(365/period)log(E[R])', clabel='Vol DC'
    ),
    lambda ax: plots.plot_mmean(
      title="Norm Mean (365/period)log(E[R]) by RF",
      ax=ax, ydomain=nydomain, mmeans=mmeans_rf, yname='nmmean', y2name='enmmean', gname='rfg', ylabel='(365/period)log(E[R])', clabel='RF Group'
    )
  ])

def c_adj_mmean(df, mmean_):
  mmean_orig = mmean_
  def mmean_(*args):
    return mmean_orig(*args) ** 0.85

  mmeans_vol_rf, mmeans_vol, mmeans_rf = mmeans_by_vol_rf(df, mmean_), mmeans_by_vol(df, mmean_), mmeans_by_rf(df, mmean_)

  plots.plot_mmeans_by_period_vol_rf(
    "Adj Mean E[R] by (T, rf, vol), x - rf quantile",
    mmeans_vol_rf, x='rfg', y='mmean', y2='emmean', color='volg', facet='period_d', ydomain=(1, None)
  )

  plots.plot_mmeans_by_period_vol_rf(
    "Adj Norm Mean (365/period)log(E[R]) by (T, rf, vol), x - rf quantile",
    mmeans_vol_rf, x='rfg', y='nmmean', y2='enmmean', color='volg', facet='period_d', ydomain=(0, 0.3)
  )

  ydomain = (1, 1.5)
  plots.plot_grid("Adj Mean E[R] by (T, vol) and (T, rf)", [
    lambda ax: plots.plot_mmean(
      title="Mean E[R] by vol",
      ax=ax, ydomain=ydomain, mmeans=mmeans_vol, yname='mmean', y2name='emmean', gname='vol_dc', ylabel='E[R]', clabel='Vol Group',
    ),
    lambda ax: plots.plot_mmean(
      title="Mean E[R] by RF",
      ax=ax, ydomain=ydomain, mmeans=mmeans_rf, yname='mmean', y2name='emmean', gname='rfg', ylabel='E[R]', clabel='RF Group'
    ),
  ])

  nydomain = (0, 0.25)
  plots.plot_grid("Adj Norm Mean (365/period)log(E[R]) by (T, vol) and (T, rf)", [
    lambda ax: plots.plot_mmean(
      title="Norm Mean (365/period)log(E[R]) by vol",
      ax=ax, ydomain=nydomain, mmeans=mmeans_vol, yname='nmmean', y2name='enmmean', gname='vol_dc', ylabel='(365/period)log(E[R])', clabel='Vol DC'
    ),
    lambda ax: plots.plot_mmean(
      title="Norm Mean (365/period)log(E[R]) by RF",
      ax=ax, ydomain=nydomain, mmeans=mmeans_rf, yname='nmmean', y2name='enmmean', gname='rfg', ylabel='(365/period)log(E[R])', clabel='RF Group'
    )
  ])

def run():
  # report(doc_before, False)
  df, lr_t2_orig = prepare_data()
  mmean_ = estimate_mean(df)

  c_adjust_data_mmean(df, lr_t2_orig)
  c_estimate_mmean(df, mmean_)
  c_adj_mmean(df, mmean_)

  report(doc_after, False)

if __name__ == "__main__":
  run()