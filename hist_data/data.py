import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(__file__, '..', '..')))
import pandas as pd
import numpy as np
from hist_data.add_bankrupts import add_bankrupts

def add_fields(df):
  df['t']   = pd.to_datetime(df['t'], format='%Y-%m-%d', errors='raise')
  df['vol'] = df['scale_d_t']

def assign_quantiles(df, cname, qname, dcname, dcmian):
  x = df[cname].values
  ranks = np.argsort(np.argsort(x))
  q = (ranks + 1) / len(x)
  df[qname] = q
  df[dcname] = np.minimum((q * 10).astype(int) + 1, 10)
  df[dcmian] = df.groupby(dcname)[cname].transform('median')

def load():
  df = pd.read_csv(f'hist_data/returns-step-month.tsv.zip', sep='\t', compression='zip')
  add_fields(df)
  assign_quantiles(df, 'vol', 'vol_q', 'vol_dc', 'vol_dc_mian')
  return df

def load_with_bankrupts():
  df_all = pd.read_csv(f'hist_data/returns-step-month.tsv.zip', sep='\t', compression='zip')
  periods = sorted(df_all['period_d'].unique())

  def get_data_for_period(period_d):
    df = df_all[df_all['period_d'] == period_d].copy()
    add_fields(df)

    assign_quantiles(df, 'vol', 'vol_q', 'vol_dc', 'vol_dc_mian')
    df = add_bankrupts(df, period_d, ['lr_t2', 'lr_t2_min', 'lr_t2_max'])
    # add fields for bankrupts and reassign quantiles with account for bankrupts
    add_fields(df)
    assign_quantiles(df, 'vol', 'vol_q', 'vol_dc', 'vol_dc_mian')
    return df

  return pd.concat(get_data_for_period(p) for p in periods)

# def adjust_data_mmean(df):
#   # Description and charts in `/mean`

#   # Adjusting means of vol9 and vol10
#   adjustments = [
#     # vol10
#     [10, 30,   0.95],
#     [10, 60,   0.85],
#     [10, 91,   0.76],
#     [10, 182,  0.68],
#     [10, 365,  0.68],
#     [10, 730,  0.74],
#     [10, 1095, 0.73],
#     # vol9
#     [9,  30,   0.98],
#     [9,  60,   0.93],
#     [9,  91,   0.96],
#     [9,  182,  0.97],
#     [9,  365,  0.93],
#     [9,  730,  0.93],
#     [9,  1095, 0.95],

#   ]
#   for vol_dc, period, factor in adjustments:
#     df.loc[(df['period_d'] == period) & (df['vol_dc'] == vol_dc), 'lr_t2'] *= factor