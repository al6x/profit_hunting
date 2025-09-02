Estimating tail exponent of stock log returns

Run `julia tail/tail.jl`.

### Goal

Estimate left and right tails for stock log returns, for 1d, 30d, 365d periods and volatility
levels, from historical data.

Normal US NYSE+NASDAQ stock only, no penny stock like AMEX or OTC.

### Results

![](readme/tails-by-periods-x-period-y-color-type-dashed-model.png)

Results depends on how returns normalised, varying 2.7-3.2.

Note 30d has x30 less data than 1d returns, still it should be enough to estimate the tail.
Periods >=60d less realiable, they have much less data, and maybe the data bias more prominent.

Mathematically the exponent should be resistant to aggregation `Pr(X>x|for large x) ~ Cx^-ν`, but
it may not be true for a) if x sampled from differrent distributions and b) pre asymptotic
c) bounded x.

In my opinion larger periods follow `ν = a + b log T`, solving it for 1d and 30d:

```
ν_l_model(t) = 3.0 + 0.2352log(t);
ν_r_model(t) = 3.1 + 0.4705log(t);
```

### Methodology

- Historical log returns `log r_t2 = log S_t/S_t2` for `t in [1d, 30d, ..., 1095d]`.
- Volatility `nvol_t = 0.8 current_vol_t + 0.2 historical_vol`, where current over recent period
  `EMA[MAD[log r]]*sqrt(pi/2)` and historical `MAD[log r]*sqrt(pi/2)` over long period.
- Normalise log returns as `log r_t2 / nvol_t`, each return individually.
- Decluster per stock, allow no more than 1 tail event within window = 30d for 1d returns and
  larger windows for longer periods.
- Allow clusters across stocks - when many stock drop on same day.
- EVT POT GPD approach with [DEDH-HILL](/tail-estimator) estimator.

Data has 3.4m days. Reliable estimation require 10k sample size or <340d periods, rough
estimation 5k or <680d. And if grouped by 10 volatility levels <34d and for 5 vol levels <68d.

Data has both omission (bankrupts) and comission biases - so tails may be a bit wrong.

### Other studies

Results depend on return normalisation, so may be different.

**Study1**: [Tail Index Estimation: QuantileDriven Threshold Selection](https://www.bankofcanada.ca/wp-content/uploads/2019/08/swp2019-28.pdf)
, one of authors is Laurens de Haan, pioneer of EVT and inventor of one of the best estimators
"DEDH", so I guess numbers they got analysing CRSP stock returns are worth to consider.

Results from KS estimator: left tail 3.4, right tail 2.97 from [Table 7](docs/study1-table7.jpg).
Estimator has bias 3/2.85 from [Table 1](docs/study1-table1.jpg). Correcting results left tail
3.4 * 3/2.85 = 3.58, right tail 2.97 * 3/2.85 = 3.13.

**Study2**: various mentions by N. Taleb that tails ~3.

### Data

Daily prices of 250 stocks all starting with 1972, [details](/hist_data)`.

1d and 30d returns calculated with moving window(size=30, step-30).

For larger periods >=60d, cacluation a bit more complex, using cohorts, you can ignore details
and just consider it as multiple version of same returns, you will see it as multiple lines
on plots with periods >=60d. It's used to get more information from the data and avoid
overlapping bias, correlation, returns calculated as moving window(start=cohort, size=period,
step=period), each cohort shifts initial position by +30.

### Questions

I used unusual estimator [Tail Estimator](/tail-estimator) that in my opinion is much better and
apply normalisation by volatility and choose tail threshold differently.

My data is biased, no bankrupts, if you have access to full market unbiased data,
**let me know** please, I would be interested to analyse it.

If you find errors or know a better way, let me know please.

### TODO

- In order to avoid submission bias - estimate tail for each stock individually and analyse it.
- Calculate credible intervals.

### Tails, normalised

1d tails on chart start with lower probability because 1d has more data and higher treshold
quantile.

Left Tail (Norm) x=survxn, y=survy(cohort), dashed=survy_m by=period

![Left Tail (Norm) x=survxn, y=survy(cohort), dashed=survy_m by=period](readme/left-tail-norm-x-survxn-y-survy-cohort-dashed-survy-m-by-period.png)

Left Tail (Norm) by periods

```
3×3 DataFrame
 Row │ period  ν        ν_model
     │ Int64   Float64  Float64
─────┼──────────────────────────
   1 │      1      3.0      3.0
   2 │     30      3.8      3.8
   3 │     60      4.8      4.0
```

Right Tail (Norm) x=survxn, y=survy(cohort), dashed=survy_m by=period

![Right Tail (Norm) x=survxn, y=survy(cohort), dashed=survy_m by=period](readme/right-tail-norm-x-survxn-y-survy-cohort-dashed-survy-m-by-period.png)

Right Tail (Norm) by periods

```
3×3 DataFrame
 Row │ period  ν        ν_model
     │ Int64   Float64  Float64
─────┼──────────────────────────
   1 │      1      3.1      3.1
   2 │     30      4.7      4.7
   3 │     60      4.7      5.0
```

### Tails by Vol, normalised

Left Tail by Vol (Norm) raw x=survx, y=survy, color=vol_dc(cohort), dashed=survy_m by=period

![Left Tail by Vol (Norm) raw x=survx, y=survy, color=vol_dc(cohort), dashed=survy_m by=period](readme/left-tail-by-vol-norm-raw-x-survx-y-survy-color-vol-dc-cohort-dashed-survy-m-by-period.png)

Left Tail by Vol (Norm) x=survxn, y=survy, color=vol_dc(cohort), dashed=survy_m by=period

![Left Tail by Vol (Norm) x=survxn, y=survy, color=vol_dc(cohort), dashed=survy_m by=period](readme/left-tail-by-vol-norm-x-survxn-y-survy-color-vol-dc-cohort-dashed-survy-m-by-period.png)

Left Tail by Vol (Norm) table

```
2×2 DataFrame
 Row │ period  ν
     │ Int64   Float64
─────┼─────────────────
   1 │      1      3.0
   2 │     30      3.9
```

```
20×5 DataFrame
 Row │ period  cohort  vol_dc  tail_k  ν
     │ Int64   Int64   Int64   Int64   Float64
─────┼─────────────────────────────────────────
   1 │      1       0       1     947      3.0
   2 │      1       0       2     967      2.8
   3 │      1       0       3     983      2.9
   4 │      1       0       4     980      3.1
   5 │      1       0       5     989      3.3
   6 │      1       0       6     986      3.6
   7 │      1       0       7     993      3.1
   8 │      1       0       8     995      3.1
   9 │      1       0       9     981      3.1
  10 │      1       0      10     904      3.5
  11 │     30       0       1     228      3.9
  12 │     30       0       2     232      4.0
  13 │     30       0       3     235      4.1
  14 │     30       0       4     235      3.9
  15 │     30       0       5     235      3.6
  16 │     30       0       6     235      3.4
  17 │     30       0       7     235      6.8
  18 │     30       0       8     236      3.9
  19 │     30       0       9     234      6.9
  20 │     30       0      10     215      6.9
```

Right Tail by Vol (Norm) raw x=survx, y=survy, color=vol_dc(cohort), dashed=survy_m by=period

![Right Tail by Vol (Norm) raw x=survx, y=survy, color=vol_dc(cohort), dashed=survy_m by=period](readme/right-tail-by-vol-norm-raw-x-survx-y-survy-color-vol-dc-cohort-dashed-survy-m-by-period.png)

Right Tail by Vol (Norm) x=survxn, y=survy, color=vol_dc(cohort), dashed=survy_m by=period

![Right Tail by Vol (Norm) x=survxn, y=survy, color=vol_dc(cohort), dashed=survy_m by=period](readme/right-tail-by-vol-norm-x-survxn-y-survy-color-vol-dc-cohort-dashed-survy-m-by-period.png)

Right Tail by Vol (Norm) table

```
2×2 DataFrame
 Row │ period  ν
     │ Int64   Float64
─────┼─────────────────
   1 │      1      3.5
   2 │     30      4.7
```

```
20×5 DataFrame
 Row │ period  cohort  vol_dc  tail_k  ν
     │ Int64   Int64   Int64   Int64   Float64
─────┼─────────────────────────────────────────
   1 │      1       0       1     933      3.5
   2 │      1       0       2     950      3.2
   3 │      1       0       3     972      3.5
   4 │      1       0       4     972      3.5
   5 │      1       0       5     985      3.5
   6 │      1       0       6     988      3.9
   7 │      1       0       7     990      4.2
   8 │      1       0       8     984      3.8
   9 │      1       0       9     972      4.0
  10 │      1       0      10     960      3.8
  11 │     30       0       1     226      6.6
  12 │     30       0       2     228      4.0
  13 │     30       0       3     228      7.0
  14 │     30       0       4     236      7.3
  15 │     30       0       5     235      4.4
  16 │     30       0       6     236      7.4
  17 │     30       0       7     237      4.4
  18 │     30       0       8     236      5.5
  19 │     30       0       9     233      7.5
  20 │     30       0      10     228      7.1
```

### Tails by RSI, normalised

Left Tail by RSI (Norm) raw x=survx, y=survy, color=rsi_dc(cohort), dashed=survy_m by=period

![Left Tail by RSI (Norm) raw x=survx, y=survy, color=rsi_dc(cohort), dashed=survy_m by=period](readme/left-tail-by-rsi-norm-raw-x-survx-y-survy-color-rsi-dc-cohort-dashed-survy-m-by-period.png)

Left Tail by RSI (Norm) x=survxn, y=survy, color=rsi_dc(cohort), dashed=survy_m by=period

![Left Tail by RSI (Norm) x=survxn, y=survy, color=rsi_dc(cohort), dashed=survy_m by=period](readme/left-tail-by-rsi-norm-x-survxn-y-survy-color-rsi-dc-cohort-dashed-survy-m-by-period.png)

Left Tail by RSI (Norm) table

```
2×2 DataFrame
 Row │ period  ν
     │ Int64   Float64
─────┼─────────────────
   1 │      1      3.0
   2 │     30      3.5
```

```
20×5 DataFrame
 Row │ period  cohort  rsi_dc  tail_k  ν
     │ Int64   Int64   Int64?  Int64   Float64
─────┼─────────────────────────────────────────
   1 │      1       0       1     955      3.3
   2 │      1       0       2     995      3.0
   3 │      1       0       3     991      3.2
   4 │      1       0       4     996      3.4
   5 │      1       0       5     997      3.2
   6 │      1       0       6     995      3.1
   7 │      1       0       7     992      2.9
   8 │      1       0       8     998      3.0
   9 │      1       0       9     997      3.4
  10 │      1       0      10     992      2.9
  11 │     30       0       1     234      7.0
  12 │     30       0       2     233      5.0
  13 │     30       0       3     237      4.8
  14 │     30       0       4     235      3.4
  15 │     30       0       5     237      4.0
  16 │     30       0       6     236      4.3
  17 │     30       0       7     236      3.2
  18 │     30       0       8     236      2.9
  19 │     30       0       9     237      3.8
  20 │     30       0      10     236      6.8
```

Right Tail by RSI (Norm) raw x=survx, y=survy, color=rsi_dc(cohort), dashed=survy_m by=period

![Right Tail by RSI (Norm) raw x=survx, y=survy, color=rsi_dc(cohort), dashed=survy_m by=period](readme/right-tail-by-rsi-norm-raw-x-survx-y-survy-color-rsi-dc-cohort-dashed-survy-m-by-period.png)

Right Tail by RSI (Norm) x=survxn, y=survy, color=rsi_dc(cohort), dashed=survy_m by=period

![Right Tail by RSI (Norm) x=survxn, y=survy, color=rsi_dc(cohort), dashed=survy_m by=period](readme/right-tail-by-rsi-norm-x-survxn-y-survy-color-rsi-dc-cohort-dashed-survy-m-by-period.png)

Right Tail by RSI (Norm) table

```
2×2 DataFrame
 Row │ period  ν
     │ Int64   Float64
─────┼─────────────────
   1 │      1      3.4
   2 │     30      4.3
```

```
20×5 DataFrame
 Row │ period  cohort  rsi_dc  tail_k  ν
     │ Int64   Int64   Int64?  Int64   Float64
─────┼─────────────────────────────────────────
   1 │      1       0       1     983      3.4
   2 │      1       0       2     997      3.6
   3 │      1       0       3     994      3.3
   4 │      1       0       4     990      4.1
   5 │      1       0       5     998      4.2
   6 │      1       0       6     997      3.8
   7 │      1       0       7     991      3.3
   8 │      1       0       8     989      3.4
   9 │      1       0       9     986      3.4
  10 │      1       0      10     941      3.7
  11 │     30       0       1     233      7.2
  12 │     30       0       2     236      7.2
  13 │     30       0       3     237      4.8
  14 │     30       0       4     237      7.5
  15 │     30       0       5     235      7.2
  16 │     30       0       6     236      4.0
  17 │     30       0       7     236      4.3
  18 │     30       0       8     233      4.1
  19 │     30       0       9     232      4.5
  20 │     30       0      10     231      7.0
```

### Tails by Vol and RF rate, normalised

Left Tail by Vol, RF (Norm) νs x=lr_rf_medn, y=ν, color=vol_dc

![Left Tail by Vol, RF (Norm) νs x=lr_rf_medn, y=ν, color=vol_dc](readme/left-tail-by-vol-rf-norm-s-x-lr-rf-medn-y-color-vol-dc.png)

Right Tail by Vol, RF (Norm) νs x=lr_rf_medn, y=ν, color=vol_dc

![Right Tail by Vol, RF (Norm) νs x=lr_rf_medn, y=ν, color=vol_dc](readme/right-tail-by-vol-rf-norm-s-x-lr-rf-medn-y-color-vol-dc.png)

### Tails for all periods, normalised

Left Tail all Periods (Norm) x=survxn, y=survy(cohort), dashed=survy_m by=period

![Left Tail all Periods (Norm) x=survxn, y=survy(cohort), dashed=survy_m by=period](readme/left-tail-all-periods-norm-x-survxn-y-survy-cohort-dashed-survy-m-by-period.png)

Left Tail all Periods (Norm) by periods

```
8×3 DataFrame
 Row │ period  ν        ν_model
     │ Int64   Float64  Float64
─────┼──────────────────────────
   1 │      1      3.0      3.0
   2 │     30      3.8      3.8
   3 │     60      4.8      4.0
   4 │     91      6.7      4.1
   5 │    182      6.5      4.2
   6 │    365      6.6      4.4
   7 │    730      5.3      4.6
   8 │   1095      4.5      4.6
```

Right Tail all Periods (Norm) x=survxn, y=survy(cohort), dashed=survy_m by=period

![Right Tail all Periods (Norm) x=survxn, y=survy(cohort), dashed=survy_m by=period](readme/right-tail-all-periods-norm-x-survxn-y-survy-cohort-dashed-survy-m-by-period.png)

Right Tail all Periods (Norm) by periods

```
8×3 DataFrame
 Row │ period  ν        ν_model
     │ Int64   Float64  Float64
─────┼──────────────────────────
   1 │      1      3.1      3.1
   2 │     30      4.7      4.7
   3 │     60      4.7      5.0
   4 │     91      4.5      5.2
   5 │    182      5.1      5.5
   6 │    365      5.8      5.9
   7 │    730      6.0      6.2
   8 │   1095      7.2      6.4
```

Tails by periods x=period, y=ν, color=type, dashed=ν_model

![Tails by periods x=period, y=ν, color=type, dashed=ν_model](readme/tails-by-periods-x-period-y-color-type-dashed-model.png)

