import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(__file__, '..', '..')))
import pandas as pd
import numpy as np
from add_bankrupts import add_bankrupts

def add_fields(df):
  df['t']   = pd.to_datetime(df['t'], format='%Y-%m-%d', errors='raise')
  df['vol'] = df['scale_d_t']

def assign_quantiles(df, cname, qname, dcname):
  x = df[cname].values
  ranks = np.argsort(np.argsort(x))
  q = (ranks + 1) / len(x)
  df[qname] = q
  df[dcname] = np.minimum((q * 10).astype(int) + 1, 10)

def load():
  df = pd.read_csv(f'hist_data/returns-step-month.tsv.zip', sep='\t', compression='zip')
  add_fields(df)
  assign_quantiles(df, 'vol', 'vol_q', 'vol_dc')
  return df

def load_with_bankrupts():
  df_all = pd.read_csv(f'hist_data/returns-step-month.tsv.zip', sep='\t', compression='zip')
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