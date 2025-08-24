using DataFrames, Random, Statistics, StatsBase, Optim, JSON, VegaLite

includet.(["../lib/Lib.jl", "../lib/Report.jl", "../lib/helpers.jl", "./plots.jl"])
using .Lib, .Report

includet("../tail-estimator/lib.jl")

Random.seed!(0)
Report.configure!(report_path="tail/readme.md", asset_path="tail/readme", asset_url_path="readme")

function assign_quantiles!(ds, name)
  ranks = ordinalrank(ds[!, name])
  q = (ranks .- 1) ./ (length(ds[!, name]) - 1)

  ds[!, "$(name)_q"] = q
  ds[!, "$(name)_dc"] = min.(floor.(Int, q .* 10) .+ 1, 10)
  ds[!, "$(name)_g5"] = min.(floor.(Int, q .* 5) .+ 1, 5)
  ds
end

prepare_data_daily() = begin
  ds = cached("distr-prepare-data-daily") do
    df = pyimport("hist_data.data").load("hist_data/returns-daily.tsv.zip")
    DataFrame(df.reset_index(drop=true).to_dict(orient="list"))
  end

  ds.period = ds.period_d
  ds.lr = ds.lr_t2
  ds.lr_rf = ds.lr_rf_1y_t

  ds = vcat([begin
    assign_quantiles!(g, :vol)
    assign_quantiles!(g, :lr_rf)
    g
  end for g in groupby(ds, :period)]...)

  ds
end

prepare_data() = begin
  ds = cached("distr-prepare-data-periods") do
    df = pyimport("hist_data.data").load("hist_data/returns-periods.tsv.zip")
    DataFrame(df.reset_index(drop=true).to_dict(orient="list"))
  end

  ds.period = ds.period_d
  ds.lr = ds.lr_t2
  ds.lr_rf = ds.lr_rf_1y_t

  ds = vcat([begin
    assign_quantiles!(g, :vol)
    assign_quantiles!(g, :lr_rf)
    g
  end for g in groupby(ds, :period)]...)

  ds
end

report(read("$(@__DIR__)/readme.t.md", String))

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

group_by_period_cohort(op, ds) = begin
  DataFrame(combine(groupby(ds, [:period, :cohort])) do g
    period, cohort = g.period[1], g.cohort[1]
    results = op(g, period, cohort)
    spread((; period, cohort, results...))
  end)
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

  1d tails on chart start with lower probability because 1d has more data and treshold
  quantile for the tail is higher.
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

calc_right_tail_by_vol(ds, period, _, _) = begin
  tq = optimal_tail_quantile(nrow(ds))
  calc_tail(ds.lr, tq, period <= 60);
end;

calc_left_tail_by_vol(ds, period, _, _) = begin
  tq = optimal_tail_quantile(nrow(ds))
  calc_tail(-ds.lr, tq, period <= 60);
end;

c_tail_by_vol(name, calc, max_period=1095) = begin
  by_vol = vcat(
    group_by_period_cohort_vol(calc, ds_d),
    group_by_period_cohort_vol(calc, ds[ds.period .<= max_period, :])
  );

  plot_xyc_by(
    "$name raw", by_vol;
    x="survx", y="survy", y2="survy_m", color="vol_dc", by="period", detail="cohort",
    yscale="log", xscale="log",
    xdomain=(0.03, 4), ydomain=(2e-6, 0.015)
  );

  plot_xyc_by(
    name, by_vol;
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

# Tails on raw returns -----------------------------------------------------------------------------
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

report("""
  # Estimating tail of raw log returns

  1d and 30d are most interesting. Periods >=60d have much less data and show for visual comparison
  only. Multiple lines on >=60d periods are cohorts, ignore it.
""")
c_tail("Right Tail", calc_right_tail)
c_tail("Left Tail", calc_left_tail)
c_tail("Left Tail with Bankrupts", calc_left_tail_with_bankrupts, 60)

println("Done")