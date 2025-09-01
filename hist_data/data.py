import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(__file__, '..', '..')))
import pandas as pd
import numpy as np
from hist_data.add_bankrupts import add_bankrupts

def add_fields(df):
  df['vol'] = df['scale_d_t']
  df['t']   = pd.to_datetime(df['t'], format='%Y-%m-%d', errors='raise').dt.date
  df['t2']  = pd.to_datetime(df['t'], format='%Y-%m-%d', errors='raise').dt.date
  if 'period_d' not in df.columns:
    df['period_d'] = 1
  if 'cohort' not in df.columns:
    df['cohort'] = 0

def assign_quantiles(df, cname, qname, dcname, dcmian=None):
  x = df[cname].values
  ranks = np.argsort(np.argsort(x))
  q = (ranks + 1) / len(x)
  df[qname] = q
  df[dcname] = np.minimum((q * 10).astype(int) + 1, 10).astype(int)
  if dcmian is not None:
    df[dcmian] = df.groupby(dcname)[cname].transform('median')

def make_each_year_have_even_counts_of_records(df):
  df = df.copy()
  # Assert each year represented evenly
  # year_counts = df['t'].dt.year.value_counts()
  # last_year = df['t'].dt.year.max()
  # if year_counts[last_year] / year_counts.max() < 0.8:
  #   print(f"W Dropping last year {last_year}, too little data: {year_counts[last_year]} < {year_counts.max()}")
  #   df = df[df['t'].dt.year != last_year]

  # first_year = df['t'].dt.year.min()
  # if year_counts[first_year] / year_counts.max() < 0.8:
  #   print(f"W Dropping first year {first_year}, too little data: {year_counts[first_year]} < {year_counts.max()}")
  #   df = df[df['t'].dt.year != first_year]

  year_counts = df['t'].dt.year.value_counts()
  def assert_all_years_present(df):
    y = df['t'].dt.year
    full = np.arange(y.min(), y.max()+1)
    missing = np.setdiff1d(full, y.unique())
    if missing.size: raise AssertionError(f"Missing years: {missing.tolist()}")
  assert_all_years_present(df)

  if year_counts.min() / year_counts.max() < 0.6:
    def plot_year_counts(df):
      import matplotlib.pyplot as plt
      final_counts = df['t'].dt.year.value_counts().sort_index()
      final_counts.plot(kind='bar', figsize=(12, 4), title='Rows per Year (Not balanced)')
      plt.xlabel('Year'); plt.ylabel('Row Count'); plt.tight_layout(); plt.show()
    plot_year_counts(df)
    raise AssertionError("Uneven year counts min/max < 0.6")

  # Resample each year to match max count
  df['year'] = df['t'].dt.year
  max_n = df['year'].value_counts().max()
  def upsample(g):
    if len(g) < max_n:
      extra = g.sample(n=max_n - len(g), replace=True)
      return pd.concat([g, extra], ignore_index=True)
    return g
  balanced = df.groupby('year', group_keys=False).apply(upsample).reset_index(drop=True)
  balanced = balanced.drop(columns='year')

  return balanced

def load(fname='hist_data/returns-periods.tsv.zip'):
  df = pd.read_csv(fname, sep='\t', compression='zip')
  # df = pd.read_csv(fname, sep='\t')
  add_fields(df)

  out = []
  for _, idx in df.groupby('period_d').groups.items():
    sub = df.loc[idx].copy()
    assign_quantiles(sub, 'vol', 'vol_q', 'vol_dc', 'vol_dc_mian')
    out.append(sub)
  return pd.concat(out, ignore_index=True)

def load_with_bankrupts(fname='hist_data/returns-periods.tsv.zip'):
  df_all = pd.read_csv(fname, sep='\t', compression='zip')
  # df_all = pd.read_csv(fname, sep='\t')
  add_fields(df_all)

  out, qcols = [], ['vol_q','vol_dc','vol_dc_mian']
  for (period_d, cohort), idx in df_all.groupby(['period_d','cohort']).groups.items():
    df = df_all.loc[idx].copy()

    assign_quantiles(df, 'vol', *qcols)
    df = add_bankrupts(df, period_d, ['lr_t2','lr_t2_min','lr_t2_max'])
    # df = make_each_year_have_even_counts_of_records(df)

    # add_fields(df) # recompute with bankrupts included
    # assign_quantiles(df, 'vol', *qcols)

    out.append(df)

  return pd.concat(out, ignore_index=True)

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