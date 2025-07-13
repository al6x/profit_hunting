import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(__file__, '..', '..')))
import pandas as pd
import numpy as np
from returns250.add_bankrupts import add_bankrupts
from lib.helpers import cached

def prepare(df):
  strike_qs = np.arange(1, 100, 2)/100 # [1..99, step 2]
  rows = []
  periods = np.sort(df['period_d'].unique())
  for period in periods:
    df_p = df[df['period_d'] == period]
    vol_dcs = np.sort(df_p['vol_dc'].unique())

    for vol_dc in vol_dcs:
      sub = df_p[df_p['vol_dc'] == vol_dc]
      vol = sub['vol'].median()
      # mean_hscale = sub['hscale_d'].mean()
      discounts = np.exp(-(period/365) * sub['lr_rf_1y_t'])
      lreturns = sub['lr_t2']; returns = np.exp(lreturns)
      lreturns_min = sub['lr_t2_min']; returns_min = np.exp(lreturns_min)
      lreturns_max = sub['lr_t2_max']; returns_max = np.exp(lreturns_max)

      # Location depends on vol, using median as more robust estimation than mean
      lmean_t2 = np.mean(lreturns)
      scale_t2 = np.mean(np.abs(lreturns - lmean_t2))*np.sqrt(np.pi/2)
      scalep_t2 = np.mean(np.abs(lreturns[lreturns > lmean_t2] - lmean_t2)) * np.sqrt(np.pi / 2)
      scalen_t2 = np.mean(np.abs(lreturns[lreturns < lmean_t2] - lmean_t2)) * np.sqrt(np.pi / 2)
      assert (lreturns >= lreturns_min).all(), "lreturns must be >= lreturns_min"

      # Strikes should be determined on 'lr_t2' not on 'lr_t2_min'
      strikes = np.quantile(returns, strike_qs)

      for i, k in enumerate(strikes):
        # Data is doubled in bankrupt adding and overlapping used for periods >30d, so count is not statistically
        # significant
        count = len(sub)
        call_itm_p = np.count_nonzero((returns - k) > 0) / count
        call_premium_exp = np.mean(discounts*np.maximum((returns - k), 0))
        call_premium_max = np.mean(discounts*np.maximum(returns_max - k, 0))

        put_itm_p = np.count_nonzero((k - returns) > 0) / count
        put_premium_exp = np.mean(discounts*np.maximum(k - returns, 0))
        put_premium_max = np.mean(discounts*np.maximum(k - returns_min, 0))

        assert call_premium_max >= call_premium_exp, "call premium_max must be >= premium_exp"
        assert put_premium_max >= put_premium_exp, "put premium_max must be >= premium_exp"
        rows.append({
          'period': period,
          'k': round(k, 4), 'kq': round(strike_qs[i], 4),
          'vol': round(vol, 4), 'vol_dc': vol_dc,

          'p_itm_p': round(put_itm_p, 4),
          'p_exp': round(put_premium_exp, 4),
          'p_max': round(put_premium_max, 4),

          'c_itm_p': round(call_itm_p, 4),
          'c_exp': round(call_premium_exp, 4),
          'c_max': round(call_premium_max, 4),

          'scale_t2': round(scale_t2, 4),
          'scalep_t2': round(scalep_t2, 4),
          'scalen_t2': round(scalen_t2, 4),
          'lmean_t2': round(lmean_t2, 4),
          # 'tscale_t2': round(scale_t2, 4),
          # 'ltmean_t2': round(lmean_t2, 4),
          # 'hscale': mean_hscale,
        })

  df = pd.DataFrame(rows)
  df.to_csv('option_norm/data/put_premiums.tsv', sep='\t', index=False)

def add_fields(df):
  df['t']   = pd.to_datetime(df['t'], format='%Y-%m-%d', errors='raise')
  df['vol'] = df['scale_d_t']

def assign_quantiles(df, cname, qname, dcname):
  x = df[cname].values
  ranks = np.argsort(np.argsort(x))
  q = (ranks + 1) / len(x)
  df[qname] = q
  df[dcname] = np.minimum((q * 10).astype(int) + 1, 10)

def load_with_bankrupts():
  df_all = pd.read_csv(f'returns250/returns-step-month.tsv.zip', sep='\t', compression='zip')
  periods = sorted(df_all['period_d'].unique())

  def get_data_for_period(period_d):
    df = df_all[df_all['period_d'] == period_d].copy()
    add_fields(df)

    assign_quantiles(df, 'vol', 'vol_q', 'vol_dc')
    df = add_bankrupts(df, period_d, ['lr_t2', 'lr_t2_min', 'lr_t2_max'])
    # add fields for bankrupts and reassign quantiles with account for bankrupts
    add_fields(df)
    assign_quantiles(df, 'vol', 'vol_q', 'vol_dc')
    return df

  return pd.concat(get_data_for_period(p) for p in periods)

def run():
  df = cached('option-norm-df', load_with_bankrupts)
  prepare(df)

if __name__ == '__main__':
  run()
  print("Done")