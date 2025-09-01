import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(__file__, '..', '..')))
import pandas as pd
import numpy as np
from hist_data.data import load_with_bankrupts
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

def run():
  df = cached('option-norm-df', load_with_bankrupts)
  prepare(df)

if __name__ == '__main__':
  run()
  print("Done")