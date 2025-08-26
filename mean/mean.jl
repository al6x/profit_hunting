includet.(["../lib/Lib.jl", "../lib/Report.jl", "../lib/helpers.jl", "./plots.jl", "./lib.jl"])

using DataFrames, Random, Statistics, StatsBase, Optim, JSON
using .Lib, .Report

Random.seed!(0)
Report.configure!(report_path="mean/readme.md", asset_path="mean/readme", asset_url_path="readme");
py"""
from lib.helpers import configure_report
configure_report(report_path="mean/readme.md", asset_path="mean/readme", asset_url_path='readme')
"""

norm_mean(mmean, period) = log.(mmean) * (365 / period);
denorm_mean(nmmean, period) = exp.(nmmean * period / 365);
empir_mmean(lrs) = mean(exp.(lrs));

function c_explore_mmean(ds_trunc, ds_orig)
  calc(ds) = begin
    m = empir_mmean(ds.lr)
    (; mean=m, nmean=norm_mean(m, ds.period[1]))
  end

  means_vol_rf = group_by_vol_rf(ds_trunc, calc; volg=:volg, rfg=:rfg)
  means_vol_rf_orig = group_by_vol_rf(ds_orig, calc; volg=:volg, rfg=:rfg)
  means_vol_rf.adjusted = means_vol_rf.mean
  means_vol_rf.nadjusted = means_vol_rf.nmean
  means_vol_rf.original = means_vol_rf_orig.mean
  means_vol_rf.noriginal = means_vol_rf_orig.nmean

  means_vol = group_by_vol(ds_trunc, calc; volg=:vol_dc)
  means_vol_orig = group_by_vol(ds_orig, calc; volg=:vol_dc)
  means_vol.mean2  = means_vol_orig.mean
  means_vol.nmean2 = means_vol_orig.nmean

  means_rf  = group_by_rf(ds_trunc, calc; rfg=:rfg)
  means_rf_orig  = group_by_rf(ds_orig, calc; rfg=:rfg)
  means_rf.mean2   = means_rf_orig.mean
  means_rf.nmean2  = means_rf_orig.nmean

  plot_by_vol_by_rf(
    "Mean E[R]", means_vol, means_rf;
    ylabel="E[R]", solid_label="adjusted", y="mean", y2="mean2", ydomain=(1, 1.8)
  )

  plot_by_vol_by_rf(
    "Norm E[R]", means_vol, means_rf;
    ylabel="Norm E[R]", solid_label="adjusted", y="nmean", y2="nmean2", ydomain=(0, 0.35)
  )

  ydomain, nydomain = (1.0, 1.6), (0, 0.4)
  let ds = means_vol_rf
    # x - rf
    plot_xyc_by(
      "Mean E[R]", ds;
      x="lr_rf", y="adjusted", y2="original", color="volg", by="period", ydomain=ydomain
    )
    plot_xyc_by(
      "Norm Mean (365/period)log(E[R])", ds;
      x="lr_rf", y="nadjusted", y2="noriginal", color="volg", by="period", ydomain=nydomain
    )

    # x - vol
    plot_xyc_by(
      "Mean E[R]", ds;
      x="vol", y="adjusted", y2="original", color="rfg", by="period", ydomain=ydomain
    )
    plot_xyc_by(
      "Norm Mean (365/period)log(E[R])", ds;
      x="vol", y="nadjusted", y2="noriginal", color="rfg", by="period", ydomain=nydomain
    )
  end
end;

function c_explore_lmean(ds_trunc, ds_orig; rfg, nydomain)
  calc(ds) = begin
    m = mean(ds.lr)
    (; mean=m, nmean=m*(365 / ds.period[1]))
  end

  means_vol_rf = group_by_vol_rf(ds_trunc, calc; volg=:volg, rfg)
  means_vol_rf_orig = group_by_vol_rf(ds_orig, calc; volg=:volg, rfg)
  means_vol_rf.adjusted = means_vol_rf.mean
  means_vol_rf.nadjusted = means_vol_rf.nmean ./ (means_vol_rf.vol/0.015)
  means_vol_rf.original = means_vol_rf_orig.mean
  means_vol_rf.noriginal = means_vol_rf_orig.nmean ./ (means_vol_rf.vol/0.015)

  means_vol = group_by_vol(ds_trunc, calc; volg=:vol_dc)
  means_vol_orig = group_by_vol(ds_orig, calc; volg=:vol_dc)
  means_vol.mean2  = means_vol_orig.mean
  means_vol.nmean2 = means_vol_orig.nmean

  means_rf  = group_by_rf(ds_trunc, calc; rfg)
  means_rf_orig  = group_by_rf(ds_orig, calc; rfg)
  means_rf.mean2   = means_rf_orig.mean
  means_rf.nmean2  = means_rf_orig.nmean

  plot_by_vol_by_rf(
    "Log Mean E[log R] $rfg", means_vol, means_rf;
    ylabel="E[log R]", solid_label="adjusted", y="mean", y2="mean2", ydomain=(-0.05, 0.4)
  )

  plot_by_vol_by_rf(
    "Norm Log Mean (365/period)(E[log R]) $rfg", means_vol, means_rf;
    ylabel="(365/period)(E[log R])", solid_label="adjusted", y="nmean", y2="nmean2", ydomain=(-0.05, 0.15)
  )

  ydomain = (-0.05, 0.35)
  let ds = means_vol_rf
    # x - rf
    plot_xyc_by(
      "Log Mean E[log R] $rfg", ds;
      x="lr_rf", y="adjusted", y2="original", color="volg", by="period", ydomain=ydomain
    )
    plot_xyc_by(
      "Norm Log Mean (365/period)E[log R] $rfg", ds;
      x="lr_rf", y="nadjusted", y2="noriginal", color="volg", by="period", ydomain=nydomain
    )

    # x - vol
    plot_xyc_by(
      "Log Mean E[log R] $rfg", ds;
      x="vol", y="adjusted", y2="original", color="rfg", by="period", ydomain=ydomain
    )
    plot_xyc_by(
      "Norm Log Mean (365/period)E[log R] $rfg", ds;
      x="vol", y="nadjusted", y2="noriginal", color="rfg", by="period", ydomain=nydomain
    )
  end
end

# Run ----------------------------------------------------------------------------------------------
report("""
  Estimating expected stock return E[R] from historical data.

  Exploring the `{T, Vol, RF Rate, E[R]}` shape.

  Run `julia mean/mean.jl`.
""")

ds = prepare_data();
ds_orig = deepcopy(ds);

# Adjusting data
# tq = 1-1/3650;
adjust_data_lr!(ds)

# Truncating to once in 10y event for 10 stocks
# ds = truncate_by_period_volg_cohort(ds, (period) -> 1/((365/period)*10*10));

report("""
  # Exploring Mean E[R]

  Simulated bankrupts added, details `../hist_data/readme.md`.

  Vol deciles 9,10 are visibly distorted, suppressing mean to make it look visibly same as 1-8 deciles. Mean suppressed
  as `log(r)^k(period, vol_dc) for vol_dc in 9, 10`. It distorts the distribution shape, but ok for mean.

  Limiting mean to once in 10y events. Truncating upper tail by 1/3650 quantile. Because of positive skewed heavy tails
  mean is very sensitive to positive rare events, large event once in 100 year event may influence mean. Strictly
  speaking the true mean should account for once in 100 y events, so our estimation is not true mean. The 10y treshold
  also looks to be good as it's has almost no effect on the observable mean.
""")
c_explore_mmean(ds, ds_orig);

report("# Exploring Log Mean E[log R] with 5 rf groups")
c_explore_lmean(ds, ds_orig, rfg=:rfg, nydomain = (-0.2, 0.3));

report("# Exploring Log Mean E[log R] with 10 rf groups")
c_explore_lmean(ds, ds_orig; rfg=:rf_dc, nydomain = (-0.3, 0.4));

report("""
# Data

Details `../hist_data/readme.md`.

  - volg - volatility group
  - rfg - risk free rate group
"""; print=false)

println("Done.")