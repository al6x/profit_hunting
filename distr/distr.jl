includet.(["../lib/Lib.jl", "../lib/Report.jl", "../lib/helpers.jl", "./plots.jl",
  "../lib/skewt.jl", "./lib.jl"]);

using DataFrames, Random, Statistics, StatsBase, Optim, JSON
using .Lib, .Report

Random.seed!(0);
Report.configure!(report_path="distr/readme.md", asset_path="distr/readme", asset_url_path="readme");
py"""
from lib.helpers import configure_report
configure_report(report_path="distr/readme.md", asset_path="distr/readme", asset_url_path='readme')
"""
version = 1;

ds = prepare_data();
ds_d = prepare_data_daily();
ds_orig = deepcopy(ds);
ds_d_orig = deepcopy(ds_d);

# Adjusting data
# adjust_data_lr!(ds)

# Truncating to once in 10y event for 10 stocks
tail_tp(period) = 1/((365/period)*10*10);

# Truncating to once in 10y event for 10 stocks
# ds = truncate_by_period_volg_cohort(ds, (period) -> 1/((365/period)*10*10));
# ds_d = truncate_by_period_volg_cohort(ds_d, (period) -> 1/((365/period)*10*10));

# function c_explore_distr(ds_trunc, ds_orig)
  fit_d(ds) = begin
    period, volg, rfg = ds.period[1], ds.volg[1], ds.rfg[1]
    println("estimating $((; period, volg, rfg))")

    d = fit(SkewT, ds.lr)
    mmean = mean_exp(d; l=quantile(d, tail_tp(period)), h=quantile(d, 1-tail_tp(period)))
    (; μ, σ, ν, λ) = d

    nmmean = log(mmean) * (365 / period)
    nμ = μ * (365 / period)
    nσ = σ * (365 / sqrt(period))

    (; μ, σ, ν, λ, mmean, nmmean, nμ, nσ)
  end;

  merge_orig!(ds, ds_orig) = begin
    ds.μ_orig = ds_orig.μ
    ds.σ_orig = ds_orig.σ
    ds.ν_orig = ds_orig.ν
    ds.λ_orig = ds_orig.λ
    ds.mmean_orig = ds_orig.mmean

    ds.nμ_orig = ds_orig.nμ
    ds.nσ_orig = ds_orig.nσ
    ds.nmmean_orig = ds_orig.nmmean
  end;

  vol_rf = cached("distr-group-by-vol-rf-$version") do
    vcat(
      group_by_vol_rf(ds_d, fit_d; volg=:volg, rfg=:rfg),
      group_by_vol_rf(ds,   fit_d; volg=:volg, rfg=:rfg)
    )
  end;
  # vol_rf_orig = cached("distr-group-by-vol-rf-orig-$version") do
  #   vcat(
  #   group_by_vol_rf(ds_orig, fit_d; volg=:volg, rfg=:rfg)
  # end;
  # merge_orig!(vol_rf, vol_rf_orig);

  # x - rf
  # ν
  plot_xyc_by(
    "ν - tail exponent", vol_rf;
    x="lr_rf", y="ν", color="volg", by="period", ydomain=(2, 10),
    mark=:line_with_points
  )

  # λ
  plot_xyc_by(
    "λ - skew", vol_rf;
    x="lr_rf", y="λ", color="volg", by="period", ydomain=(-0.3, 0.1),
    mark=:line_with_points
  )

  # μ
  plot_xyc_by(
    "μ", vol_rf;
    x="lr_rf", y="μ", color="volg", by="period", ydomain=(-0.05, 0.35),
    mark=:line_with_points
  )

  plot_xyc_by(
    "μ 1d zoomed", vol_rf[vol_rf.period .== 1,:];
    x="lr_rf", y="μ", color="volg", by="period", ydomain=(-0.001, 0.0015),
    mark=:line_with_points
  )

  plot_xyc_by(
    "nμ", vol_rf;
    x="lr_rf", y="nμ", color="volg", by="period", ydomain=(-0.2, 0.4),
    mark=:line_with_points
  )

  # σ
  plot_xyc_by(
    "σ", vol_rf;
    x="lr_rf", y="σ", color="volg", by="period",
    mark=:line_with_points
  )

  plot_xyc_by(
    "σ 1d zoom", vol_rf[vol_rf.period .== 1,:];
    x="lr_rf", y="σ", color="volg", by="period",
    mark=:line_with_points
  )

  plot_xyc_by(
    "nσ", vol_rf;
    x="lr_rf", y="nσ", color="volg", by="period", ydomain=(0, 16),
    mark=:line_with_points
  )

  # E[R]
  plot_xyc_by(
    "E(R)", vol_rf;
    x="lr_rf", y="mmean", color="volg", by="period", ydomain=(0.98, 1.6),
    yscale="log", mark=:line_with_points
  )
  plot_xyc_by(
    "Norm E(R) as E(R) (365/period)", vol_rf;
    x="lr_rf", y="nmmean", color="volg", by="period", ydomain=(-0.1, 0.45),
    mark=:line_with_points
  )

  # x - vol
  report("Volatility for 1 d calculated differently and has different scale")

  # ν
  plot_xyc_by(
    "ν - tail exponent", vol_rf;
    x="vol", y="ν", color="rfg", by="period", ydomain=(2, 10),
    mark=:line_with_points
  )

  # λ
  plot_xyc_by(
    "λ - skew", vol_rf;
    x="vol", y="λ", color="rfg", by="period", ydomain=(-0.3, 0.1),
    mark=:line_with_points
  )

  # μ
  plot_xyc_by(
    "μ", vol_rf;
    x="vol", y="μ", color="lr_rf", by="period", ydomain=(-0.05, 0.35),
    mark=:line_with_points
  )

  plot_xyc_by(
    "μ 1d zoomed", vol_rf[vol_rf.period .== 1,:];
    x="vol", y="μ", color="lr_rf", by="period", ydomain=(-0.001, 0.0015),
    mark=:line_with_points
  )

  plot_xyc_by(
    "nμ", vol_rf;
    x="vol", y="nμ", color="rfg", by="period", ydomain=(-0.2, 0.4),
    mark=:line_with_points
  )

  # σ
  plot_xyc_by(
    "nσ", vol_rf;
    x="vol", y="nσ", color="rfg", by="period", ydomain=(0, 16),
    mark=:line_with_points
  )

  # E[R]
  plot_xyc_by(
    "E(R)", vol_rf;
    x="vol", y="mmean", color="rfg", by="period",
    mark=:line_with_points
  )

  plot_xyc_by(
    "Norm E(R) as E(R) (365/period)", vol_rf;
    x="vol", y="nmmean", color="rfg", by="period", ydomain=(-0.1, 0.45),
    mark=:line_with_points
  )

  # by vol
  vols = cached("distr-group-by-vol-$version") do
    vcat(
      group_by_vol(ds_d, fit_d; volg=:vol_dc),
      group_by_vol(ds, fit_d; volg=:vol_dc)
    )
  end;
  vols[vols.period .== 1, :]

  # vols_orig = cached("distr-group-by-vol-orig-$version") do
  #   group_by_vol(ds_orig, fit_d; volg=:vol_dc)
  # end
  # merge_orig!(vols, vols_orig);

  # by rf
  rfs = cached("distr-group-by-rf-$version") do
    vcat(
      group_by_rf(ds_d, fit_d; rfg=:rfg),
      group_by_rf(ds, fit_d; rfg=:rfg)
    )
  end;
  # rfs_orig = cached("distr-group-by-rf-orig-$version") do
  #   group_by_rf(ds_orig, fit_d; rfg=:rfg)
  # end
  # merge_orig!(rfs, rfs_orig);

  # ν
  plot_by_vol_by_rf(
    "ν", vols, rfs;
    ylabel="ν", y="ν", ydomain=nothing, xscale="log"
  )

  # μ
  plot_by_vol_by_rf(
    "μ", vols, rfs;
    ylabel="μ", y="μ", ydomain=(-0.05, 0.35)
  )

  plot_by_vol_by_rf(
    "Norm μ as μ 365/T", vols[vols.period .> 1, :], rfs[rfs.period .> 1, :];
    ylabel="Norm μ", y="nμ", ydomain=(-0.05, 0.15), xscale="log"
  )

  # σ
  plot_by_vol_by_rf(
    "σ", vols, rfs;
    ylabel="σ", y="σ", ydomain=(0.001, 0.8), xscale="log"
  )
  vols[vols.period .== 1, :]
  fit(SkewT, ds_d[(ds_d.period .== 1) .& (ds_d.vol_dc .== 1), :].lr)
  plot_by_vol_by_rf(
    "Norm σ as σ 365/√T", vols, rfs;
    ylabel="Norm σ", y="nσ", ydomain=(2, 12), xscale="log"
  )

  # λ
  plot_by_vol_by_rf(
    "λ", vols, rfs;
    ylabel="λ", solid_label="adjusted", y="λ", ydomain=nothing, xscale="log"
  )

  # E[R]
  plot_by_vol_by_rf(
    "E(R)", vols, rfs;
    ylabel="E[R]", solid_label="adjusted", y="mmean", ydomain=(1, 1.8)
  )

  plot_by_vol_by_rf(
    "Norm E(R) as log(E(R)) 365/T", vols[vols.period .> 1, :], rfs[rfs.period .> 1, :];
    ylabel="Norm E[R]", solid_label="adjusted", y="nmmean", ydomain=(0.025, 0.3), xscale="log"
  )

  a=1
# end


# Run ----------------------------------------------------------------------------------------------
report("""
  Estimating expected stock return E[R] from historical data.

  Exploring the `{T, Vol, RF Rate, E[R]}` shape.

  Run `julia mean/mean.jl`.
"""; print=false)

ds = prepare_data();
ds_orig = deepcopy(ds);

# Adjusting data
tq = 1-1/3650;
adjust_data_lr!(ds)
ds = truncate_ds(ds, tq);

# report("""
#   # Exploring Mean E[R]

#   Simulated bankrupts added, details `../hist_data/readme.md`.

#   Vol deciles 9,10 are visibly distorted, suppressing mean to make it look visibly same as 1-8 deciles. Mean suppressed
#   as `log(r)^k(period, vol_dc) for vol_dc in 9, 10`. It distorts the distribution shape, but ok for mean.

#   Limiting mean to once in 10y events. Truncating upper tail by 1/3650 quantile. Because of positive skewed heavy tails
#   mean is very sensitive to positive rare events, large event once in 100 year event may influence mean. Strictly
#   speaking the true mean should account for once in 100 y events, so our estimation is not true mean. The 10y treshold
#   also looks to be good as it's has almost no effect on the observable mean.
# """)
# c_explore_mmean(ds, ds_orig)

# report("# Exploring Log Mean E[log R] with 5 rf groups")
# c_explore_lmean(ds, ds_orig, rfg=:rfg, nydomain = (-0.2, 0.3))

# report("# Exploring Log Mean E[log R] with 10 rf groups")
# c_explore_lmean(ds, ds_orig; rfg=:rf_dc, nydomain = (-0.3, 0.4))

# report("""
# # Data

# Details `../hist_data/readme.md`.

#   - volg - volatility group
#   - rfg - risk free rate group
# """; print=false)