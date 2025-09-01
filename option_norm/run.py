import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(__file__, '..', '..')))
import pandas as pd
import numpy as np
from scipy.optimize import minimize
from lib.helpers import configure_report, report
from scipy.stats import norm
from scipy.optimize import minimize
import matplotlib.pyplot as plt
import inspect
import math
from misc import prune_params, fit_multi_init
import plots

np.random.seed(0)

configure_report(report_path="option_norm/readme.md", asset_path="option_norm/readme", asset_url_path='readme')

doc_before = r"""
Option Normalisation using Historical Data

Premiums calculated for each period and vol quantile:

  C_{eu}(K|Q_{vol}) = E[e^-rT (R-K)+|Q_{vol}]
  P_{eu}(K|Q_{vol}) = E[e^-rT (K-R)+|Q_{vol}]

  where R = S_T/S_0, K = K/S_0

Each return has its own risk free rate, so separate discount applied to each point, instead of appluing single discount
to aggregated premium.

Run `python option_norm/run.py`.
"""

doc_after = """
  # Data

    - period - period, days

    - vol_dc - volatility decile 1..10
    - vol    - current moving daily volatility, as EWA(log(r)^2)^0.5, (scale unit, not variance), median of vol_dc group.

    - lmean_t2  - E[log R]
    - scale_t2  - Scale[log R] = mean_abs_dev(log R - lmean_t2) * sqrt(pi/2)

    - k  - strike
    - kq - strike quantile

    - p_exp - realised put premium using price at expiration (lower bound, european option)
    - p_max - realised put premium, using min price during option lifetime (upper bound, max possible
      for american option).
    - p_itm - realised probability of put ITM

    - c_exp - realised call premium using price at expiration (lower bound, european option)
    - c_max - realised call premium, using max price during option lifetime (upper bound, max possible
      for american option).
    - c_itm - realised probability of call ITM


  Daily prices for 250 stocks all starting from 1973 till 2025, stats aggregated with moving window with step 30d, so
  larger periods have overlapping. Dividends ignored. Data has survivorship bias, no bankrupts.

  Data adjusted by adding bankrupts. The **annual bankruptsy probability** conditional on company volatility with total
  annual rate P(b|T=365) = 0.5% to drop to x0.1.
"""

def load():
  df = pd.read_csv('option_norm/data/put_premiums.tsv', sep='\t')
  return df

def estimate_mmean(df):
  report("""
    # Estimating Mean E[R]

    Estimating from historicaly realised

      E_hist[R] = exp(E[log R] + 0.5*Scale[log R]^2)
      E_pred[R]  = model(period, vol | P)
      P ~ min L2[weight (log E_pred[R] - log E_hist[R])]

    Positive scale used, to avoid inflating mean by negative skew, although effect is minimal.

    Loss is weighted, to make errors equal across vols and periods.

    1 and 9 vol deciles boost, as they look to be well shaped. As a side effect, the model underestimates mean at
    long >730d periods, it's desired, because the dataset has survivorship bias.

    Vol decile 10 ignored, it's too noisy. As result model understimates mean for 10 vol decile, it's desired.

    Longer periods calculated with overlapping step 30d, and less reliably, so lowering weight a bit.

      weight = 1/period^2/vol^0.5
      weight[vol_dc in (1, 9)] *= 1.5
  """)

  # Only unique subset of the data needed, it's same across different strikes
  df = df[df.vol_dc != 10] # Too noisy, ignoring
  df = df[['period', 'lmean_t2', 'scalep_t2', 'vol', 'vol_dc']].drop_duplicates().sort_values('period').reset_index(drop=True)

  lmmean_observed = df['lmean_t2'] + 0.5*df['scalep_t2']**2 # observed E[R]

  def lmmean_(period, vol, P):
    ty = period/365
    center_vol = P[1]
    return (
      P[0] + P[2]*ty + P[3]*vol*ty # General trend
      + P[4]*(np.abs(center_vol-vol)/ty)**0.25 # Making spread sensitive to volatility difference from the center
      + P[5]*ty**2 # Bending curve down slightly for long periods
    )

  # Make errors equal across vols and periods.
  # Boosting 1 and 9 deciles, as they look to be well shaped. Also, the dataset has survivorship bias, and
  # boosting 1 quantile has positive effect by lowering the mean of higher quantiles at >730d periods.
  weights = 1/df['period']**2/df['vol']**0.5
  weights[df['vol_dc'].isin([1, 9])] *= 1.5
  weights = weights / np.mean(weights)
  def loss(params):
    lmmean = lmmean_(df['period'], df['vol'], params)
    errors = np.abs((lmmean - lmmean_observed)*weights)**2
    return 1e6*np.mean(errors)

  init = [-0.0012, 0.0075, 0.0435, 3.4766, 0.0035, -0.0062]
  def fit(loss, init):
    # return minimize(loss, x0=init, method='L-BFGS-B')
    return minimize(loss, x0=init, method='Powell')

  # prune_params(loss=loss, fit=fit, init=init, min_params=4)
  # Best 4-param model loss=1.3821, kept=(1, 2, 3, 4)
  # Best 5-param model loss=1.1764, kept=(0, 1, 2, 3, 4)
  # Best 6-param model loss=1.1718, kept=(0, 1, 2, 3, 4, 5)

  # inits = []
  # P = tuple(fit_multi_init(loss, inits, fit))

  P = tuple(fit(loss, init).x)
  # P = cached('lmmean', lambda: tuple(fit(loss, init).x))
  report(f"Found params: [{', '.join(f'{x:.4f}' for x in P)}], loss: {loss(P):.4f}")

  return lambda period, vol: np.exp(lmmean_(period, vol, P))

def estimate_scale(df):
  report("""
    # Estimating Scale[log R]

    Estimating from historicaly realised

      Scale_pred[log R] = model(period, vol | P)
      P ~ min L2[weight(Scale_pred[log R] - Scale_hist[log R])]

    Loss is weighted, to make errors equal across vols and periods. Longer periods calculated with overlapping step 30d,
    and less reliably, so lowering weight a bit.

      weight = 1/Scale_hist[log R]/period^0.5
  """)

  # We only need an unique subset of the data, it's the same across different strikes
  df = df[['period', 'scale_t2', 'vol', 'vol_dc']].drop_duplicates().sort_values('period').reset_index(drop=True)

  def scale_(period, vol, P):
    lp, lv = np.log(period), np.log(vol)
    return np.exp(
      P[0] + P[1]*lv + P[2]*lp + P[3]*lp**2 + P[4]*lv**2 + P[5]*lv*lp + P[6]*lv**3 + P[7]*lv*lp**2 + P[8]*lv**2*lp
    )

  # Optimal model of 7 params
  def scale7_(period, vol, P):
    lp, lv = np.log(period), np.log(vol)
    return np.exp(
      P[0] + P[1]*lv + P[2]*lp + P[3]*lp**2 + P[4]*lv**2 + P[7]*lv*lp**2 + P[8]*lv**2*lp
    )
  scale_ = scale7_

  # Make errors equal across vols and periods
  # Lower weight of loner periods slightly, because they calculated with overlapping step 30d and have more
  # noise (maybe use a better weighting approach).
  weights = 1/df.scale_t2/np.sqrt(df.period)
  weights = weights / np.mean(weights)
  def loss(params):
    scale = scale_(df['period'], df['vol'], params)
    # reg = np.sum(np.abs(params[3:]))  # Penalise only higher-order terms
    return 1e6*np.mean((weights*(scale - df.scale_t2))**2) #+ 0.5*reg

  init = [-0.5207, 1.9198, 1.2038, -0.1444, 0.2550, 0.0000, 0.0000, -0.0349, -0.0437]
  def fit(loss, init):
    return minimize(loss, x0=init)

  # prune_params(loss=loss, fit=fit, init=init, min_params=4)
  # Best 4-param model loss=3.9269, kept=(1, 2, 4, 8)
  # Best 5-param model loss=3.2666, kept=(0, 1, 4, 5, 8)
  # Best 6-param model loss=1.9299, kept=(1, 2, 3, 4, 7, 8)
  # Best 7-param model loss=1.4333, kept=(0, 1, 2, 3, 4, 7, 8)
  # Best 8-param model loss=1.4260, kept=(0, 1, 2, 3, 4, 5, 7, 8)
  # Best 9-param model loss=1.4209, kept=(0, 1, 2, 3, 4, 5, 6, 7, 8)

  P = tuple(fit(loss, init).x)
  # P = cached('scale', lambda: tuple(fit(loss, init).x))
  report(f"Found params: [{', '.join(f'{x:.4f}' for x in P)}], loss: {loss(P):.4f}")

  return lambda period, vol: scale_(period, vol, P)

def c_mmean(df, mmean_):
  report("# Mean E[R | T, vol]")

  def mean_fitting_info():
    sub = df.drop_duplicates(subset=['period','vol_dc']).copy()

    sub['mmean_true'] = np.exp(sub.lmean_t2 + 0.5*df.scale_t2**2)
    sub['mmean_model'] = sub.apply(lambda r: mmean_(r.period, r.vol), axis=1)

    plots.plot_lmean(
      "Mean E[R], by period and vol (model - solid lines)",
      sub, True
    )

    def save_mmean_rel_error():
      sub['mmean_rel_error'] = round(sub.mmean_model / sub.mmean_true, 4)
      sub[['period', 'vol_dc', 'mmean_rel_error']] \
        .sort_values(['period', 'vol_dc']) \
        .to_csv('data/out/mmean_rel_error.csv', index=False)
    # save_mmean_rel_error()

  mean_fitting_info()

  plots.plot_lmean_heatmap(
    "Mean E[R]",
    mmean_=mmean_, df=df,
    vol_range=(df['vol'].min(), df['vol'].max()), period_range=(df['period'].min(), df['period'].max()),
  )

def c_scale(df, scale_):
  report("# Scale[log R | T, vol]")

  plots.plot_estimated_scale('Estimated Scale (at expiration)', df, scale_)

  plots.plot_vols_by_periods('Vol by period, as EMA((log r)^2)^0.5', df)

def c_skew(df):
  report("# Skew")

  df = df[['period', 'lmean_t2', 'scale_t2', 'scalep_t2', 'scalen_t2', 'vol_dc']].drop_duplicates() \
    .sort_values(['period', 'vol_dc'])
  mmean = np.exp(df['lmean_t2'] + 0.5*df['scale_t2']**2)
  mmeanp = np.exp(df['lmean_t2'] + 0.5*df['scalep_t2']**2)

  plots.plot_mmean_ratio("scalen_t2 vs scalep_t2, x - sort(period,vol)", df['scale_t2']/df['scalep_t2'])
  plots.plot_mmean_ratio("MMean E[R] with scale vs scalep, x - sort(period,vol)", mmean/mmeanp)

def c_normalised_strikes(df, scale_, mmean_):
  report("""
    # Strike normalisation

      E_pred[R]         = predict_mmean(period, vol | P)
      Scale_pred[log R] = predict_scale(period, vol | P)
      E_pred[log R]     = log E[R]_pred - 0.5*Scale_pred[log R]^2
      m = (log(K) - E_pred[log R])/Scale_pred[log R]

    Compared to true normalised strike

      m_true = (log(K) - E_hist[log R])/Scale_hist[log R]

    Normalising strike using mean, scale is biased as doesn't account for the distribution shape (skew, tails). But
    should be consistent across periods and volatilities, as distribution should be similar.

    Thre's minor mistake `E[log R] = log E[R] - 0.5*Scale[log R]^2` should use positive part of scale, but error is
    very small, ignoring.
  """)
  scales = scale_(df['period'], df['vol'])
  mmeans = mmean_(df['period'], df['vol'])
  df['m']      = (np.log(df['k']) - (np.log(mmeans) - 0.5*scales**2)) / scales

  df['m_true'] = (np.log(df['k']) - df['lmean_t2']) / df['scale_t2']

  plots.plot_strikes_vs_strike_quantiles_by_period(
    "Normalised Strikes vs True Normalised Strikes",
    df, x='m', y='m_true', min=-4, max=4
  )

def c_premiums(df):
  report("# Premium")

  df = df.copy()
  mmeans = np.exp(df['lmean_t2'] + 0.5*df['scalep_t2']**2)
  scales = df['scale_t2']

  df['np_exp'] = df['p_exp']/mmeans/scales
  df['nc_exp'] = df['c_exp']/mmeans/scales

  report("Raw Strike K")

  plots.plot_premium_by_period(
    "Premium P, Raw Strike K",
    df, x='k', x_title='k', p='p_exp', c='c_exp', x_min=0.5, x_max=2, y_min=0, y_max=0.2, yscale='linear', xscale='log'
  )
  plots.plot_premium_by_period(
    "Premium P, Raw Strike K, log scale",
    df, x='k', x_title='k', p='p_exp', c='c_exp', x_min=0.5, x_max=2, y_min=0.001, y_max=0.5, yscale='log', xscale='log'
  )

  # Normalised strikes as ITM probabilities
  report("Norm Strike `P(R < K | vol)` (probability of ITM or F(d2) from BlackScholes)")

  plots.plot_premium_by_period(
    "Premium, Norm Strike P(R < K | vol)",
    df, x='kq', x_title='p', p='p_exp', c='c_exp', x_min=0, x_max=1, y_min=0, y_max=0.2
  )
  # plots.plot_premium_by_period(
  #   "Premium, Norm Strike as P(R < K | vol), log scale",
  #   df, x='kq', x_title='p', p='p_exp', c='c_exp', x_min=0, x_max=1, y_min=0.001, y_max=0.2, yscale='log'
  # )

  # Normalised strikes as z score
  report("Norm Strike `(log K - E[log R])/Scale[log R]` (z score in log space or d2 from BlackScholes)")

  plots.plot_premium_by_period(
    "Premium P, Norm Strike (log K - E[log R])/Scale[log R]",
    df, x='m_true', x_title='Norm Strike', p='p_exp', c='c_exp', x_min=-4, x_max=4, y_min=0, y_max=0.2, yscale='linear'
  )
  plots.plot_premium_by_period(
    "Premium P, Norm Strike (log K - E[log R])/Scale[log R], log scale",
    df, x='m_true', x_title='Norm Strike', p='p_exp', c='c_exp', x_min=-4, x_max=4, y_min=0.001, y_max=0.2, yscale='log'
  )

  report("# Norm Premium")

  report("Normalising premium as `P/E[R]/Scale[log R]`")

  plots.plot_premium_by_period(
    "Norm Premium P/E[R]/Scale[log R], Norm Strike (log K - E[log R])/Scale[log R]",
    df, x='m_true', x_title='Norm Strike', p='np_exp', c='nc_exp', x_min=-4, x_max=4, y_min=0, y_max=1, yscale='linear'
  )
  plots.plot_premium_by_period(
    "Norm Premium P/E[R]/Scale[log R], Norm Strike (log K - E[log R])/Scale[log R], log scale",
    df, x='m_true', x_title='Norm Strike', p='np_exp', c='nc_exp', x_min=-4, x_max=4, y_min=0.005, y_max=1, yscale='log'
  )

  plots.plot_premium_by_period(
    "Norm Premium P/E[R]/Scale[log R], Norm Strike P(R < K | vol)",
    df, x='kq', x_title='p', p='np_exp', c='nc_exp', x_min=0, x_max=1, y_min=0, y_max=1
  )
  # plots.plot_premium_by_period(
  #   "Norm Premium P/E[R]/Scale[log R], Norm Strik P(R < K | vol), log scale",
  #   df, x='kq', x_title='p', p='np_exp', c='nc_exp', x_min=0, x_max=1, y_min=0.005, y_max=1, yscale='log'
  # )

  report("# Ratio of Premium at expiration to max possible over option lifetime")

  plots.plot_ratio_by_period("Ratio of Premium Min / Exp (calls solid)", df)
  report("#note bounds for american call: eu < am < 2eu")

def run():
  report(doc_before, False)

  df = load()
  df = df[(df.period != 1095)]

  mmean_ = estimate_mmean(df)
  c_mmean(df, mmean_)

  scale_ = estimate_scale(df)
  c_scale(df, scale_)

  c_normalised_strikes(df, scale_, mmean_)
  c_premiums(df)

  c_skew(df)

  report(doc_after, False)

def tmp():
  df = load()

  mmean_ = estimate_mmean(df)
  c_mmean(df, mmean_)

if __name__ == "__main__":
  run()