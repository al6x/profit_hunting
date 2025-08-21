using DataFrames, Random, Statistics, StatsBase, Optim, JSON, VegaLite

includet.(["../lib/Lib.jl", "../lib/Report.jl", "../lib/helpers.jl", "./plots.jl"])
using .Lib, .Report

includet("../tail-estimator/lib.jl")

Random.seed!(0)
Report.configure!(report_path="tail/readme.md", asset_path="tail/readme", asset_url_path="readme")

function prepare_data_daily()
  ds = cached("distr-prepare-data-daily") do
    df = pyimport("hist_data.data").load("hist_data/returns-daily.tsv.zip")
    DataFrame(df.reset_index(drop=true).to_dict(orient="list"))
  end

  ds.period = ds.period_d
  ds.lr = ds.lr_t2
  ds
end

function prepare_data()
  ds = cached("distr-prepare-data-periods") do
    df = pyimport("hist_data.data").load("hist_data/returns-periods.tsv.zip")
    DataFrame(df.reset_index(drop=true).to_dict(orient="list"))
  end

  ds.period = ds.period_d
  ds.lr = ds.lr_t2
  ds
end

report("""
  Estimating tail exponent of stock log returns

  **Goal**: Estimate left and right tails on 1d, 30d, 365d log returns, using Extreme Value Theory,
  [POT GPT DEDH-HILL method](/tail-estimator).

  Most interesting periods are 1d and 30d. Larger periods >=60d have much less data and shown for
  comparison only.

  **Results**: I think the most reliable estimation from normalised returns, estimates for raw
  return and returns grouped by volatility deciles are mostly for comparison.

  **1d**, right tail **ν=3.6**, left tail with synthetic bankrupts **ν=2.2**, left tail without
  bankrupts (the data is biased, no bankrupt distress delisting) **ν=3.2**. Maybe for the left
  tail something in between should be choosen, like **ν=2.5**, as we can't say for sure if
  synthetic bankrupts are correct approximation of real bankrupts or not.

  **30d**, right tail **ν=4.6**, left tail with synthetic bankrupts **ν=1.2**, left tail without
  bankrupts **ν=4.0**. I think it has same tails as 1d, because tail exponent resistant to
  aggregation, we observe less heavy tails for 30d because there's x30 less data. The left tail
  with synthetic bankrupts is unusually small, I guess because it's only approximation of real
  data with bankrupts, and it distort the estimator and should be ignored.

  **Larger periods >=60d** I think estimates for larger periods are wrong, because they have orders
  of magnitude less data, and so present for comparison only. I think they have same tail exponents
  as 1d, because tail exponent is resistant to aggregation.

  **Data**: Daily prices of 250 stocks all starting with 1972, [details](/hist_data)`.

  1d and 30d returns calculated with moving window(size=30, step-30).

  For larger periods >=60d, cacluation a bit more complex, using cohorts, you can ignore details
  and just consider it as multiple version of same returns, you will see it as multiple lines
  on plots with periods >=60d. It's used to get more information from the data and avoid
  overlapping bias, correlation, returns calculated as moving window(start=cohort, size=period,
  step=period), each cohort shifts initial position by +30.

  **Questions**:

  - I used approach different from standard EVT POT GPD. The standard approaches
    have problems MLE - huge bias and variance, HILL - very sensitive to threshold
    parameter and even then has bias, DEDH - the best, but still has some bias. I found combining
    DEDH-HILL gives the best result. And the threshold choosen differently, assuming that log return
    tails are somewhat similar to StudenT tails, the optimal threshold found by simulation.
    I think it's the best approach, more precise than standard EVT. It's described
    in [/tail-estimator](/tail-estimator) experiment. The standard DEDH method would produce almost
    same results.

  - I think the **tail exponent resistant to aggregation** and so should be the same for 1d,
    30d, 365d log returns. Mathematically it is so `Pr(X>x) ~ Cx^-ν`, ν doesn't depend on
    aggregation.  The empirical estimation shows different story - tail exponent is growing with
    the period, but I believe it's a random artefact, because there's much less data for
    larger periods, and in reality tail exponent is the same.

  - The data is biased, no bankrupts, so the left tail estimation as 2.2, calculated with adding
    synthetic bankrupts is approximate. If you have access to full market unbiased data,
    please **let me know**, I would be interested to analyse it, for free.

  - If you find errors or know better way, please let me know.

  **Run**: `julia tail/tail.jl`.

  # Bankrupts

  The data has survivorship bias, no bankrupt delisted stocks. Left tail exponent estimated twice,
  on raw data and data with syntetic bankrupts added.

  Syntetic bankrupts are added with 2%/year probability of `log(0.1)` return.

  Left tail exponent with syntetic banrkupt should be treated only as very approximate number and
  probably someting in between of with and without bankrupts should be used.

  If you have access to **unbiased data**, please let me know I would be interested to analyse it
  and see results.
""")

ds = prepare_data();
ds_d = prepare_data_daily();

# Optimal tail quantiles from `/tail-estimator`
optimal_tail_quantile(n) = n > 100_000 ? 0.995 : 0.985;

empir_surv(x) = begin
  # Collapsing duplicates for better plot
  n      = length(x)
  cm     = countmap(x)
  x_uniq = sort(collect(keys(cm)); rev=true)
  counts = [cm[v] for v in x_uniq]
  y      = cumsum(counts) ./ n
  x_uniq, y
end;

calc_tail(x, tq, calc_gpd) = begin
  u = quantile(x, tq)

  tail = x[x .> u]

  survx, survy = empir_surv(tail)
  survy .*= (1-tq)
  survxn = (survx .- u ) ./ u

  # For large periods there's too little data to fit the tail
  !calc_gpd && return (; survx, survxn, survy, ν=missing, survy_m=missing)

  # Fit GPD should use original tail without collapsed duplicates
  d = fit_gpd_dedh_hill((tail .- u) ./ u)

  # Model survival function for plotting
  survy_m = (1-tq) .* ccdf.(Ref(d), survxn)
  ν = 1/d.ξ
  (; survx, survxn, survy, ν, survy_m)
end;

# Tails on raw returns -----------------------------------------------------------------------------
group_by_period_cohort(op, ds) = begin
  DataFrame(combine(groupby(ds, [:period, :cohort])) do g
    period, cohort = g.period[1], g.cohort[1]
    results = op(g, period, cohort)
    spread((; period, cohort, results...))
  end)
end;

calc_right_tail(ds, period, _) = begin
  x = ds.lr
  tq = optimal_tail_quantile(length(x))
  calc_tail(x, tq, period <= 365)
end;

calc_left_tail(ds, period, _) = begin
  x = -ds.lr
  tq = optimal_tail_quantile(length(x))
  calc_tail(x, tq, period <= 365)
end;

calc_left_tail_with_bankrupts(ds, period, _) = begin
  # Adding syntethic bankrupts (distress delisting), 2%/year with return log(0.1)
  lrs = ds.lr
  years_per_row = period == 1 ? 1/(365*0.69) : period/365
  ny = length(lrs) * years_per_row
  nb = round(Int, ny * 0.02)
  br = log(0.1)
  lrs = [lrs..., fill(br, nb)...]

  x = -lrs
  tq = optimal_tail_quantile(length(x))
  calc_tail(x, tq, period <= 365)
end;

c_tail(name, calc, max_period=1095) = begin
  by_cohort = vcat(
    group_by_period_cohort(calc, ds_d),
    group_by_period_cohort(calc, ds[ds.period .<= max_period, :])
  );

  plot_xyc_by(
    name, by_cohort;
    x="survxn", y="survy", y2="survy_m", by="period", detail="cohort",
    yscale="log", xscale="log",
    xdomain=(0.05, 30), ydomain=(2e-7, 0.015)
  );

  νs = by_cohort[by_cohort.period .<= 365, [:period, :cohort, :ν]];
  νs = combine(groupby(νs, [:period, :cohort]),
    :ν => length => :tail_k, :ν => first => :ν
  );

  total = combine(groupby(νs, [:period]), :ν => median => :ν);
  total.ν = round.(total.ν, digits=1);
  total_s = sprint(print, total);

  νs.ν = round.(νs.ν, digits=1);
  grouped_s = sprint(print, νs);

  report("$name table")
  report_code(total_s)
  report_code(grouped_s)
end

report("""
  # Estimating tail of raw log returns

  1d and 30d are most interesting. Periods >=60d have much less data and show for visual comparison
  only. Multiple lines on >=60d periods are cohorts, ignore it.
""")
c_tail("Right Tail", calc_right_tail)
c_tail("Left Tail", calc_left_tail)
c_tail("Left Tail with Bankrupts", calc_left_tail_with_bankrupts, 60)

# Tails on normalised returns ----------------------------------------------------------------------
normalise_returns_by_vol(ds) = vcat([begin
  v = g.lr
  z = v .- mean(v)
  z ./ mean(abs.(z))
end for g in groupby(ds, :vol_dc)]...);

calc_right_tail_norm(ds, period, _) = begin
  x = normalise_returns_by_vol(ds)
  tq = optimal_tail_quantile(length(x))
  calc_tail(x, tq, period <= 365)
end;

calc_left_tail_norm(ds, period, _) = begin
  x = -normalise_returns_by_vol(ds)
  tq = optimal_tail_quantile(length(x))
  calc_tail(x, tq, period <= 365)
end;

calc_left_tail_norm_with_bankrupts(ds, period, _) = begin
  # Adding syntethic bankrupts (distress delisting), 2%/year with return log(0.1)
  lrsn = normalise_returns_by_vol(ds)
  years_per_row = period == 1 ? 1/(365*0.69) : period/365
  ny = length(lrsn) * years_per_row
  nb = round(Int, ny * 0.02)
  br = log(0.1)
  # Bankrupt returns also should be normalised, using stats of average returns in
  # volatility groups 5,6
  avg_lrs = ds[(ds.vol_dc .== 5) .| (ds.vol_dc .== 6), :].lr
  avg_lrs_mean = mean(avg_lrs)
  brn = (br - avg_lrs_mean) / mean(abs.(avg_lrs .- avg_lrs_mean))
  lrsn = [lrsn..., fill(brn, nb)...]

  x = -lrsn
  tq = optimal_tail_quantile(length(x))
  calc_tail(x, tq, period <= 60)
end;

report("""
  # Estimating tail of normalised log returns

  Returns grouped into 10 deciles by volatility, and each group normalised as
  `(log r - mean) / mean_abs_dev`.

  I think it's a better way to estimate tail exponent, and indeed it produces slightly lower
  tail exponent than the raw returns.

  How volatility calculated - each return treated individually and assigned volatility decile
  based on the current volatility. Current volatility calculated as previous log return
  for daily returns and EMA for larger periods. Each return treated individually, so same stock
  may have different volatility deciles for different returns.
""")

c_tail("Right Tail Norm", calc_right_tail_norm)
c_tail("Left Tail Norm", calc_left_tail_norm)
c_tail("Left Tail Norm with Bankrupts", calc_left_tail_norm_with_bankrupts, 60)

# Tails by vol -------------------------------------------------------------------------------------
group_by_period_cohort_vol(op, ds) = begin
  DataFrame(combine(groupby(ds, [:period, :cohort, :vol_dc])) do g
    period, cohort, vol_dc = g.period[1], g.cohort[1], g.vol_dc[1]
    results = op(g, period, cohort, vol_dc)
    spread((; period, cohort, vol_dc, results...))
  end)
end;

# report("1d tails on chart start with lower probability because 1d has more data and treshold
# quantile for the tail is higher")

calc_right_tail_by_vol(ds, period, _, _) = begin
  tq = optimal_tail_quantile(nrow(ds))
  calc_tail(ds.lr, tq, period <= 60);
end;

calc_left_tail_by_vol(ds, period, _, _) = begin
  tq = optimal_tail_quantile(nrow(ds))
  calc_tail(-ds.lr, tq, period <= 60);
end;

c_tail_by_vol(name, calc_by_vol, max_period=1095) = begin
  by_vol = vcat(
    group_by_period_cohort_vol(calc_by_vol, ds_d),
    group_by_period_cohort_vol(calc_by_vol, ds[ds.period .<= max_period, :])
  );

  plot_xyc_by(
    name, by_vol;
    x="survx", y="survy", y2="survy_m", color="vol_dc", by="period", detail="cohort",
    yscale="log", xscale="log",
    xdomain=(0.03, 4), ydomain=(2e-6, 0.015)
  );

  plot_xyc_by(
    "$name Norm", by_vol;
    x="survxn", y="survy", y2="survy_m", color="vol_dc", by="period", detail="cohort",
    yscale="log", xscale="log",
    xdomain=(0.05, 30), ydomain=(2e-6, 0.015)
  );

  νs = by_vol[by_vol.period .<= 60, [:period, :cohort, :vol_dc, :ν]];
  νs = combine(groupby(νs, [:period, :cohort, :vol_dc]),
    :ν => length => :tail_k, :ν => first => :ν
  );

  total = combine(groupby(νs, [:period]), :ν => median => :ν);
  total.ν = round.(total.ν, digits=1);
  total_s = sprint(print, total);

  νs.ν = round.(νs.ν, digits=1);
  grouped_s = sprint(print, νs);

  report("$name table")
  report_code(total_s)
  report_code(grouped_s)
end;

report("""
  # Estimating tail for each volatility decile

  To see if the tail exponent depends on volatility, color - volatility decile. Seems like it's
  same for all vol deciles.
""")

c_tail_by_vol("Right Tail by Vol", calc_right_tail_by_vol)
c_tail_by_vol("Left Tail by Vol", calc_left_tail_by_vol)

println("Done")