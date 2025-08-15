import pandas as pd
import numpy as np

# P(bankrupt(per year)|volatility decile)
BANKRUPT_P = {
  1  : 0.0011,
  2  : 0.0013,
  3  : 0.0016,
  4  : 0.0019,
  5  : 0.0022,
  6  : 0.0026,
  7  : 0.0038,
  8  : 0.0053,
  9  : 0.0090,
  10 : 0.0212
}

BANKRUPT_MR = 0.1 # mult return

def add_bankrupts_unevenly(df, period_d, fields):
  assert period_d == 1 or period_d >= 30, "period_d must be 1 or >= 30 days"
  assert np.issubdtype(df['t'].dtype, np.datetime64), "'t' column must be datetime"
  df = df.copy()
  df = df.sort_values(['symbol','t']).reset_index(drop=True)
  df['bankrupt'] = False

  # Simulate bankruptcies
  bankrupts = {}
  # Needed to correctly handle cases when step < period_d, to avoid testing for bankruptcy multiple times during
  # the period.
  symbol_next_trial, period_d_delta = {}, pd.Timedelta(days=period_d)
  for _, row in df.iterrows():
    symbol, t = row['symbol'], row['t']
    if symbol in bankrupts:
      continue
    if period_d > 1 and (symbol in symbol_next_trial and t < symbol_next_trial[symbol]):
      continue
    p_b = BANKRUPT_P[row['vol_dc']]

    adjust = 0.69 if period_d == 1 else 1.0 # for 1 day period the trading day year shoudl be used
    if np.random.rand() < (1 - (1 - p_b) ** (period_d / (365*adjust))):
      b = row.copy()
      for field in fields:
        b[field] = np.log(BANKRUPT_MR)
      b['bankrupt'] = True
      bankrupts[symbol] = b
    symbol_next_trial[symbol] = t + period_d_delta

  # Drop returns after bankruptcy
  drop_indices = []
  for idx, row in df.iterrows():
    symbol, t = row['symbol'], row['t']
    if symbol in bankrupts and t > bankrupts[symbol]['t']:
      drop_indices.append(idx)
  df = df.drop(drop_indices).reset_index(drop=True)

  # Add bankruptcy rows
  df = pd.concat([df] + [pd.DataFrame(bankrupts.values())], ignore_index=True)

  return df

def add_bankrupts(df, period_d, fields):
  # Assert each year represented evenly
  year_counts = df['t'].dt.year.value_counts()
  last_year = df['t'].dt.year.max()
  if year_counts[last_year] / year_counts.max() < 0.8:
    print(f"W Dropping last year {last_year}, too little data: {year_counts[last_year]} < {year_counts.max()}")
    df = df[df['t'].dt.year != last_year]

  first_year = df['t'].dt.year.min()
  if year_counts[first_year] / year_counts.max() < 0.8:
    print(f"W Dropping first year {first_year}, too little data: {year_counts[first_year]} < {year_counts.max()}")
    df = df[df['t'].dt.year != first_year]

  year_counts = df['t'].dt.year.value_counts()
  if year_counts.min() / year_counts.max() < 0.6:
    def plot_year_counts(df):
      import matplotlib.pyplot as plt
      final_counts = df['t'].dt.year.value_counts().sort_index()
      final_counts.plot(kind='bar', figsize=(12, 4), title='Rows per Year (Balanced)')
      plt.xlabel('Year'); plt.ylabel('Row Count'); plt.tight_layout(); plt.show()
    plot_year_counts(df)
    raise AssertionError("Uneven year counts min/max < 0.6")

  # Merge two uneven simulations
  df = pd.concat([
    add_bankrupts_unevenly(df, period_d, fields),
    add_bankrupts_unevenly(df, period_d, fields)
  ], ignore_index=True)

  # Resample each year to match max count
  df['year'] = df['t'].dt.year
  max_n = df['year'].value_counts().max()
  def resample_to_max(g):
    if len(g) < max_n:
      extra = g.sample(n=max_n - len(g), replace=True)
      return pd.concat([g, extra], ignore_index=True)
    return g
  balanced = df.groupby('year', as_index=False).apply(resample_to_max).reset_index(drop=True)
  balanced = balanced.drop(columns='year')

  return balanced