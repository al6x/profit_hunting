The data 250 stocks, all stocks start from 1972 and end in 2025.

    - symbol: Stock symbol

    - period_d: Period days [30, 60, 91, 182, 365, 730, 1095]
    - t: start of the period, T_0, 'YYYY-MM-DD' format

    - lr_rf_1y_t: log(risk free return 1y at time T_0)

    - lr_t2:     log return at time T, log S_T/S_0
    - lr_t2_max: max possible log return over time T log max(S_0, ..., S_T)/S_0
    - lr_t2_min: min possible log return over time T log min(S_0, ..., S_T)/S_0

    - hscale_d: historical Scale[log r]

    - scale_d_t:  current Scale[log r] as sqrt EMA[(log R)^2]
    - scalep_d_t: positive current Scale[log r] as sqrt EMA[(log R)^2] | log R > 0
    - scalen_d_t: negative current Scale[log r] as sqrt EMA[(log R)^2] | log R < 0

# Bankrupts

Data has survivorship bias, adding bankrupts explicitly.

The **annual bankruptsy probability** conditional on company volatility `P(b|σ,T=365)`. Defined as PMF for each
quantile, derived from `logit P(b∣σ,T=365)=α+βσ, β~3-4 and α = total rate`. With total bankruptcy probability per
year `P(b|T=365) = 0.5%`.

The **drop magnitude** is fixed as 0.1.

For differrent period T probability adjusted as `P(b|T) = 1 - (1 - p_b)^(T / 365)`, the drop is the same, independent
from T.

All future returns of the stock after then bankruptcy dropped. If overlapping window used the bankruptcy probability
for each symbol checked only once per period.

To compensate declining data points per year because stocks are removed, the data points for each year resampled to
make it even for every year.

To avoid losing valuable historial data after the bankruptcy event, the dataset is duplicated.