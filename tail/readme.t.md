Estimating tail exponent of stock log returns

Run `julia tail/tail.jl`.

# Goal

Estimate left and right tails for stock log returns for 1d, 30d, 365d periods, from historical data.
Normal US NYSE+NASDAQ stock only, no penny stock like AMEX or OTC.

# Results of this experiment

Tail exponents extimated in this experiment by [POT GPD DEDH-HILL estimator](/tail-estimator)
from Extreme Value Theory.

1d: normalised returns, **right tail ν=3.6, left tail ν=3.2**, left tail with synthetic bankrupts
ν=2.2.

30d: right tail ν=4.6, left tail ν=4.0, left tail with synthetic bankrupts ν=1.2. Note 30d has x30
less data than 1d returns, so numbers may be underestimated.

I think normalised returns give the most reliable estimation. Estimates for raw return and returns
grouped by volatility deciles are for comparison mostly.

Data has survivorship bias - no bankrupts stocks (distress delisted), so left tail may be wrong.
Left tail estimated two ways on original data and with synthetically added bankrupts. But,
synthetic bankrupts are approximation and for comparison mostly.

Larger periods >=60d: I think estimates for larger periods are wrong, because they have much
less data, and present for comparison only. I think they have same tail exponents as 1d, because
tail exponent is resistant to aggregation.

# Inferred Results

In my opinion: **right tail ν=3.1, left tail ν=3.1**, for all 1d-1095d periods.

It's **different from the results of this experiment**: right tail ν=3.6, left tail ν=3.2 for 1d
normalised returns, and right tail ν=4.6, left tail ν=4.0 for 30d normalised returns.

Most interesting periods are 1d and 30d. Larger periods >=60d have much less data, and shown for
comparison only, also I think most reliable are estimation from normalised returns, estimation
from raw returns and returns grouped by volatility for comparison only.

I think **30d and larger periods have same tails as 1d**, because tail exponent resistant to
aggregation, we observe less heavy tails for 30d because there's x30 less data, as for larger
periods it has so little data that estimation can't be trusted at all.

Problem - it's hard to estimate tail, and classical EVT produces enormously large errors, like
2.2-5 for true exponent 3. Other studies found similarly large errors in EVT estimates see (Study1,
Table 1).

**Study1**: "Tail Index Estimation: QuantileDriven Threshold Selection by Haan and others", one of
his author is Laurens de Haan, one of pioneers of EVT and inventor of one of the best estimators
- "DEDH", so I guess numbers they got for stock returns from CRSP in this paper worth to consider.

I found **estimator that produces much better results** - a combination of
[DEDH-HILL is more reliable](/tail-estimator) - it could be applied only to narrow case - for tails
that have shape like StudentT tails, but that's exactly what log returns are. Yet, there's still a
problem, my data is biased, so results of this experiment should be considered with suspicion.

**I think it's optimal to combine my results with other studies**, studies to consider:

Study1 - results from KS estimator: left tail 3.35, right tail 2.9 from
[Table 7](docs/study1-table7.jpg). Estimator has bias 3/2.85 from [Table 1](docs/study1-table1.jpg).
Correcting results left tail 3.35 * 3/2.85 = 3.53, right tail 2.9 * 3/2.85 = 3.05.

Sudy2 - various mentions by N. Taleb that tails ~3.

Combining results for left tail:

- My result 3.2, but my data doesn't have bankrupts, so it could be a bit lower.
- Study1 3.53.
- Taleb ~3.

I think left tail ~3.1.

Combining results for right tail:

- My result 3.6, and maybe my data also has comission bias, so maybe it could be a bit higher.
- Study1 3.05.
- Taleb ~3.

Unexpected, I thought it should be a bit higher than 3.6, yet other studies show it's more like 3.
I think it's safer to choose something in between ~3.1.

Larger periods >=30d show steady growth of tail exponents, I think it's because they have x30, x60,
x360 less data. Mathematically the exponent resistant to aggregation `Pr(X>x|for large x) ~ Cx^-ν`.
So exponent for all periods should be same as for 1d.

# Data

Daily prices of 250 stocks all starting with 1972, [details](/hist_data)`.

1d and 30d returns calculated with moving window(size=30, step-30).

For larger periods >=60d, cacluation a bit more complex, using cohorts, you can ignore details
and just consider it as multiple version of same returns, you will see it as multiple lines
on plots with periods >=60d. It's used to get more information from the data and avoid
overlapping bias, correlation, returns calculated as moving window(start=cohort, size=period,
step=period), each cohort shifts initial position by +30.

# Questions

I used approach different from standard EVT POT GPD. The standard approaches
have problems MLE - huge bias and variance, HILL - very sensitive to threshold
parameter and even then has bias, DEDH - the best, but still has some bias. I found combining
DEDH-HILL gives the best result. And the threshold choosen differently, assuming that log return
tails are somewhat similar to StudenT tails, the optimal threshold found by simulation.
I think it's the best approach, more precise than standard EVT. It's described
in [/tail-estimator](/tail-estimator) experiment. The standard DEDH method would produce almost
same results.

I think the **tail exponent resistant to aggregation** and so should be the same for 1d,
30d, 365d log returns. Mathematically it is so `Pr(X>x) ~ Cx^-ν`, ν doesn't depend on
aggregation.  The empirical estimation shows different story - tail exponent is growing with
the period, but I believe it's a random artefact, because there's much less data for
larger periods, and in reality tail exponent is the same.

The data is biased, no bankrupts, so the left tail estimation as 2.2, calculated with adding
synthetic bankrupts is approximate. If you have access to full market unbiased data,
please **let me know**, I would be interested to analyse it, for free.

If you find errors or know better way, please let me know.

# Bankrupts

The data has survivorship bias, no bankrupt delisted stocks. Left tail exponent estimated twice,
on raw data and data with syntetic bankrupts added.

Syntetic bankrupts are added with 2%/year probability of `log(0.1)` return.

Left tail exponent with syntetic banrkupt should be treated only as very approximate number and
probably someting in between of with and without bankrupts should be used.

If you have access to **unbiased data**, please let me know I would be interested to analyse it
and see results.