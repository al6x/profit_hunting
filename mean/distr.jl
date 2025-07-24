includet("./shared.jl")

function c_explore_mmeans(ds_trunc, ds_orig)

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

  rfg = :rfg
  ops = (
    mean  = (g) -> empir_mmean(g.lr)/(g.volg[1]/0.015),
    nmean = (g) -> norm_mean(empir_mmean(g.lr), g.period[1]),
  )

  means_vol_rf = group_by_vol_rf(ds_orig, ops; volg=:volg, rfg)
  means_vol_rf_trunc = group_by_vol_rf(ds_trunc, ops; volg=:volg, rfg)
  means_vol_rf.mean2  = means_vol_rf_trunc.mean
  means_vol_rf.nmean2 = means_vol_rf_trunc.nmean
  println(unique(sort(means_vol_rf.vol)))

  means_vol = group_by_vol(ds_orig, ops; volg=:vol_dc)
  means_vol_trunc = group_by_vol(ds_trunc, ops; volg=:vol_dc)
  means_vol.mean2  = means_vol_trunc.mean
  means_vol.nmean2 = means_vol_trunc.nmean

  means_rf  = group_by_rf(ds_orig, ops; rfg)
  means_rf_trunc  = group_by_rf(ds_trunc, ops; rfg)
  means_rf.mean2   = means_rf_trunc.mean
  means_rf.nmean2  = means_rf_trunc.nmean

  # plot_by_vol_by_rf(
  #   "Exploring Mean E[R]", means_vol, means_rf;
  #   ylabel="E[R]", solid_label="adjusted", y="mean", y2="mean2", ydomain=(0., 0.025) #(1, 1.8)
  # )

  # plot_by_vol_by_rf(
  #   "Exploring Norm E[R]", means_vol, means_rf;
  #   ylabel="Norm E[R]", solid_label="adjusted", y="nmean", y2="nmean2", ydomain=(0, 0.1) #(0, 0.3)
  # )

  # plot_by_vol_rf(
  #   "Exploring Mean E[R]", means_vol_rf;
  #   ylabel="E[R]", solid_label="adjusted", y="mean", y2="mean2", ydomain=(nothing, nothing) #(1, nothing)
  # )

  plot_by_vol_rf(
    "Exploring Norm E[R]", means_vol_rf;
    ylabel="Norm E[R]", solid_label="adjusted", y="nmean", y2="nmean2", ydomain=(nothing, nothing) #(0, 0.4)
  )
end
c_explore_mmeans(ds, ds_orig)


# Run ----------------------------------------------------------------------------------------------
# report(doc_before, False)
ds = prepare_data();
ds_orig = deepcopy(ds);

# Adjusting data
tq = 1-1/3650;
adjust_data_lr!(ds)
ds = truncate_ds(ds, tq);
c_explore_mmeans(ds, ds_orig)

# target = target_mmeans(ds);
# mmean_ = fit_model(ds, target);
# c_target_fitting(target, mmean_);
# c_estimate_mmean(ds, mmean_);

# report(doc_after, False)