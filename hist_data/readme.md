The data 250 stocks, all stocks start from 1972 and end in 2025.

Data stored separately [link](https://drive.google.com/drive/folders/1LEOh9t2p5BuSNCrs4A0p7FOxeD5RAn0o?usp=sharing).

Data has both comission (large cap) and omission biases (no bankrupts).

    - symbol: Stock symbol

    - period_d: Period days [30, 60, 91, 182, 365, 730, 1095]
    - t: start of the period, T_0, 'YYYY-MM-DD' format
    - cohort: Cohort to avoid overlapping moving window, there's no overlap within each cohort.

    - lr_rf_1y_t: log(risk free return 1y at time T_0)

    - lr_t2:     log return at time T, log S_T/S_0
    - lr_t2_max: max possible log return over time T log max(S_0, ..., S_T)/S_0
    - lr_t2_min: min possible log return over time T log min(S_0, ..., S_T)/S_0

    - hscale_mad_d: historical Scale[log r]

    - scale_d_t:  current Scale[log r] as sqrt EMA[(log R)^2]
    - scalep_d_t: positive current Scale[log r] as sqrt EMA[(log R)^2] | log R > 0
    - scalen_d_t: negative current Scale[log r] as sqrt EMA[(log R)^2] | log R < 0

Additional, pre computed fields

    - vol         - same as scale_d_t
    - vol_q       - vol quantile
    - vol_dc      - vol decile
    - vol_dc_mian - median vol for decile

# Bankrupts

Any distress delisting, not just legal bankrupts.

Data has omission bias - no bankrupts, adding bankrupts explicitly.

Bankrupt **probabilities**:

- Whole market annual bankruptsy probability choosen as 2%.
- Annual returns split into volatility deciles, bankrupt rate difference
  between 1 and 10 deciles choosen as x20.
- Probabilities in between calculated as `p(vol_dc) = exp a*vol_dc / normalisation` where
  a choosen to match x20 ratio `a = log(20)/9`.

Resulting table, annual bankruptsy probability by vol decile:

```
[0.29, 0.41, 0.57, 0.80, 1.11, 1.55, 2.16, 3.02, 4.21, 5.87]
```

Bankrupt **magnitude** fixed as 0.1.

Then syntetic bankrupts added, without accounting for absorbing barrier, as iid.