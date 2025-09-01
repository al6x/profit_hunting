import pandas as pd
import numpy as np

# P(bankrupt(per year)|volatility decile)
BANKRUPT_P = {
  1  : 0.00011,
  2  : 0.00013,
  3  : 0.00016,
  4  : 0.00019,
  5  : 0.00022,
  6  : 0.00026,
  7  : 0.00038,
  8  : 0.00053,
  9  : 0.00090,
  10 : 0.00212
}

BANKRUPT_MR = 0.1 # mult return

def add_bankrupts(df, period_d, fields):
  assert period_d == 1 or period_d >= 30
  df = df.copy().reset_index(drop=True)
  df['bankrupt'] = False

  bankrupts = []
  for dc, p in BANKRUPT_P.items():
    rows = df[df.vol_dc == dc]
    annual_count = len(rows) * (period_d / 365)
    n_add = int(round(annual_count * p / (1 - p)))
    if n_add <= 0: continue
    bankrupt_templates = rows.sample(n=n_add, replace=True)
    for _, r in bankrupt_templates.iterrows():
      b = r.copy()
      for f in fields: b[f] = np.log(BANKRUPT_MR)
      b.bankrupt = True
      bankrupts.append(b)

  if bankrupts: df = pd.concat([df, pd.DataFrame(bankrupts)], ignore_index=True)
  return df