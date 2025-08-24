Estimating tail exponent of stock log returns

Run `julia tail/tail.jl`.

# Goal

Estimate left and right tails for stock log returns for 1d, 30d, 365d periods, from historical data.
Normal US NYSE+NASDAQ stock only, no penny stock like AMEX or OTC.

# Results

Tail exponents extimated by [POT GPD DEDH-HILL](/tail-estimator) EVT estimator.

1d normalised returns: **right tail ν=3.6, left tail ν=3.2**, left tail with synthetic bankrupts
ν=2.2.

30d normalised returns: right tail ν=4.6, left tail ν=4.0, left tail with synthetic bankrupts ν=1.2. Note 30d has x30 less data than 1d returns, so numbers may be underestimated.

Larger periods >=60d: I think estimates for larger periods are wrong, because they have much
less data, and present for comparison only. I think they have same tail exponents as 1d, because
tail exponent is resistant to aggregation.

I think normalised returns give the most reliable estimation. Estimates for raw return and returns
grouped by volatility deciles are for comparison mostly.

Data has survivorship bias - no bankrupts stocks (distress delisted), so left tail may be wrong.
Left tail estimated two ways on original data and with synthetically added bankrupts. But,
synthetic bankrupts are approximation and for comparison mostly.

I use unusual estimator, a combination of [DEDH-HILL is more reliable](/tail-estimator), it produced
the best results. It works for narrow case only - for tails that are similar to StudentT tails,
but that's exactly what log returns are.

# Inferred Results

Problem - financial data, especially in tails are noisy and limited and may not be representative.

In my opinion: **right tail ν=3.1, left tail ν=3.1**, for all 1d-1095d periods.

It's **different from the results of this experiment**: right tail ν=3.6, left tail ν=3.2 for 1d,
and right tail ν=4.6, left tail ν=4.0 for 30d.

Reasoning - **I think it's worth to consider results of other studies**, because my data is biased.

**Study1**: [Tail Index Estimation: QuantileDriven Threshold Selection](https://www.bankofcanada.ca/wp-content/uploads/2019/08/swp2019-28.pdf)
, one of authors is Laurens de Haan, pioneer of EVT and inventor of one of the best estimators
"DEDH", so I guess numbers they got analysing CRSP stock returns are worth to consider.

Results from KS estimator: left tail 3.4, right tail 2.97 from [Table 7](docs/study1-table7.jpg). Estimator has bias 3/2.85 from [Table 1](docs/study1-table1.jpg). Correcting results left tail
3.4 * 3/2.85 = 3.58, right tail 2.97 * 3/2.85 = 3.13.

**Study2** - various mentions by N. Taleb that tails ~3.

Combining results for left tail:

- My result 3.2, but my data doesn't have bankrupts, so it could be a bit lower.
- Study1 3.58.
- Taleb ~3.

I think left tail ~3.1.

Combining results for right tail:

- My result 3.6, and maybe my data also has comission bias, so maybe it could be a bit higher.
- Study1 3.13.
- Taleb ~3.

Unexpected, I expected it should be a bit higher than 3.6, yet other studies show it's lower and
more like 3. I think it's safer to choose something in between ~3.1.

Larger periods >=30d show steady growth of tail exponents, I think it's because they have x30, x60,
x360 less data. Mathematically the exponent resistant to aggregation `Pr(X>x|for large x) ~ Cx^-ν`.
So, I think **30d and larger periods have same tails as 1d**

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
in [Tail Estimator](/tail-estimator) experiment. The standard DEDH method would produce slightly
worst results.

I think the **tail exponent resistant to aggregation** and so should be the same for 1d,
30d, 365d log returns. Mathematically it is so `Pr(X>x) ~ Cx^-ν`, ν doesn't depend on
aggregation.  The empirical estimation shows different story - tail exponent is growing with
the period, but I believe it's a random artefact, because there's much less data for
larger periods, and in reality tail exponent is the same.

My data is biased, no bankrupts, if you have access to full market unbiased data,
**let me know** please, I would be interested to analyse it.

If you find errors or know a better way, let me know please .

# Bankrupts

The data has survivorship bias, no bankrupt delisted stocks. Left tail exponent estimated twice,
on raw data and data with syntetic bankrupts added.

Syntetic bankrupts are added with 2%/year probability of `log(0.1)` return.

Left tail exponent with syntetic banrkupt should be treated only as very approximate number and
probably someting in between of with and without bankrupts should be used.

If you have access to **unbiased data**, please let me know I would be interested to analyse it
and see results.