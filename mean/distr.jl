includet("./shared.jl")
includet("../lib/skewt.jl")
includet("../lib/helpers.jl")

ds = prepare_data();
ds_orig = deepcopy(ds);

# Adjusting data
tq = 1-1/3650;
# adjust_data_lr!(ds)
ds = truncate_ds(ds, tq);

# function c_explore_tail(ds_trunc, ds_orig)
  tq = 0.01
  p_tail(ds) = begin
    x, period, step = sort(ds.lr), ds.period[1], 30

    n = length(x)
    nq = floor(Int, n * tq)

    ltail, rtail = x[1:nq], x[end-nq+1:end]


    lp, rp = (1:length(ltail)) ./ n, reverse((1:length(rtail)) ./ n)

    # Because of overlapped window with step 30d, larger periods are correlated, removing the correlated tails
    minp = (period/step)/n
    # minp *= 0.9 # just in case
    lmask, rmask = lp .>= minp, rp .>= minp
    ltail, rtail = ltail[lmask], rtail[rmask]
    lp, rp = lp[lmask], rp[rmask]

    nltail, nrtail = ltail ./ mean(ltail), rtail ./ mean(rtail)

    (; ltail, rtail, nltail, nrtail, lp, rp)
  end

  ps_vol = group_by_vol(ds, p_tail; volg=:vol_dc)

  # plot_xyc_by(
  #   "Right Tail", ps_vol;
  #   x="rtail", y="rp", y2=nothing, c="volg", by="period", pointsize=1, yscale="log", xscale="log",
  #   ydomain=(0.00002, tq)
  # )

  plot_xyc_by(
    "Norm Right Tail", ps_vol;
    x="nrtail", y="rp", y2=nothing, c="volg", by="period", pointsize=1, yscale="log", xscale="log",
    xdomain=(0.7, 5), ydomain=(0.00003, tq)
  )

  a=1
# end

# function c_explore_mmean(ds_trunc, ds_orig)
  calcv = 8
  calc(ds) = begin
    println("estimating $((ds.period[1], ds.rfg[1], ds.period[1]))")

    period = ds.period[1]
    d = fit(SkewT, ds.lr)
    mmean = mean_exp(d; l=log(1e-4), h=quantile(d, tq))
    (; μ, σ, ν, λ) = d

    nmmean = log(mmean) * (365 / period)
    nμ = μ * (365 / period)
    nσ = σ * (365 / sqrt(period))

    (; μ, σ, ν, λ, mmean, nmmean, nμ, nσ)
  end

  merge_orig!(ds, ds_orig) = begin
    ds.μ_orig = ds_orig.μ
    ds.σ_orig = ds_orig.σ
    ds.ν_orig = ds_orig.ν
    ds.λ_orig = ds_orig.λ
    ds.mmean_orig = ds_orig.mmean

    ds.nμ_orig = ds_orig.nμ
    ds.nσ_orig = ds_orig.nσ
    ds.nmmean_orig = ds_orig.nmmean
  end

  means_vol_rf = cached("distr-group-by-vol-rf-$calcv") do; group_by_vol_rf(ds, calc; volg=:volg, rfg=:rfg) end
  means_vol_rf_orig = cached("distr-group-by-vol-rf-orig-$calcv") do; group_by_vol_rf(ds_orig, calc; volg=:volg, rfg=:rfg) end
  merge_orig!(means_vol_rf, means_vol_rf_orig)

  # x - rf
  let ds = means_vol_rf
    # E[R]
    # plot_xyc_by(
    #   "E[R]", ds;
    #   x="lr_rf", y="mmean", y2="mmean_orig", c="volg", by="period"
    # )

    # plot_xyc_by(
    #   "Norm E[R] as E[R] (365/period)", ds;
    #   x="lr_rf", y="nmmean", y2="nmmean_orig", c="volg", by="period", ydomain=(-0.1, 0.45)
    # )

    # μ
    # plot_xyc_by(
    #   "nμ", ds;
    #   x="lr_rf", y="nμ", y2="nμ_orig", c="volg", by="period", ydomain=(-0.2, 0.4)
    # )

    # σ
    # plot_xyc_by(
    #   "nσ", ds;
    #   x="lr_rf", y="nσ", y2="nσ_orig", c="volg", by="period", ydomain=(0, 12)
    # )

    # ν
    plot_xyc_by(
      "ν", ds;
      x="lr_rf", y="ν", y2="ν_orig", c="volg", by="period", ydomain=(0, 15)
    )

    # λ
    # plot_xyc_by(
    #   "λ", ds;
    #   x="lr_rf", y="λ", y2=nothing, c="volg", by="period", ydomain=(-0.3, 0.1)
    # )
  end;

  # x - vol
  let ds = means_vol_rf
    # E[R]
    # plot_xyc_by(
    #   "E[R]", ds;
    #   x="vol", y="mmean", y2="mmean_orig", c="rfg", by="period"
    # )

    # plot_xyc_by(
    #   "Norm E[R] as E[R] (365/period)", ds;
    #   x="vol", y="nmmean", y2="nmmean_orig", c="rfg", by="period", ydomain=(-0.1, 0.45)
    # )

    # μ
    # plot_xyc_by(
    #   "nμ", ds;
    #   x="vol", y="nμ", y2="nμ_orig", c="rfg", by="period", ydomain=(-0.2, 0.4)
    # )

    # σ
    # plot_xyc_by(
    #   "nσ", ds;
    #   x="vol", y="nσ", y2="nσ_orig", c="rfg", by="period", ydomain=(0, 12)
    # )

    # ν
    plot_xyc_by(
      "ν", ds;
      x="vol", y="ν", y2="ν_orig", c="rfg", by="period", ydomain=(3, 10)
    )

    # λ
    # plot_xyc_by(
    #   "λ", ds;
    #   x="vol", y="λ", y2=nothing, c="rfg", by="period", ydomain=(-0.3, 0.1)
    # )
  end;

  # by vol
  means_vol = cached("distr-group-by-vol-$calcv") do; group_by_vol(ds, calc; volg=:vol_dc) end
  means_vol_orig = cached("distr-group-by-vol-orig-$calcv") do; group_by_vol(ds_orig, calc; volg=:vol_dc) end
  merge_orig!(means_vol, means_vol_orig)

  # by rf
  means_rf = cached("distr-group-by-rf-$calcv") do; group_by_rf(ds, calc; rfg=:rfg) end
  means_rf_orig = cached("distr-group-by-rf-orig-$calcv") do; group_by_rf(ds_orig, calc; rfg=:rfg) end
  merge_orig!(means_rf, means_rf_orig)

  # E[R]
  plot_by_vol_by_rf(
    "E[R]", means_vol, means_rf;
    ylabel="E[R]", solid_label="adjusted", y="mmean", y2="mmean_orig", ydomain=(1, 1.8)
  )

  plot_by_vol_by_rf(
    "Norm E[R] as log(E[R]) 365/T", means_vol, means_rf;
    ylabel="Norm E[R]", solid_label="adjusted", y="nmmean", y2="nmmean_orig", ydomain=(0.025, 0.3), xscale="log"
  )

  # μ
  plot_by_vol_by_rf(
    "μ", means_vol, means_rf;
    ylabel="μ", solid_label="adjusted", y="μ", y2="μ_orig", ydomain=(-0.05, 0.35)
  )

  plot_by_vol_by_rf(
    "Norm μ as μ 365/T", means_vol, means_rf;
    ylabel="Norm μ", solid_label="adjusted", y="nμ", y2="nμ_orig", ydomain=(-0.05, 0.15), xscale="log"
  )

  # σ
  plot_by_vol_by_rf(
    "σ", means_vol, means_rf;
    ylabel="σ", solid_label="adjusted", y="σ", y2="σ_orig", ydomain=(0.05, 0.8), xscale="log"
  )

  plot_by_vol_by_rf(
    "Norm σ as σ 365/√T", means_vol, means_rf;
    ylabel="Norm σ", solid_label="adjusted", y="nσ", y2="nσ_orig", ydomain=(2, 12), xscale="log"
  )

  # ν
  plot_by_vol_by_rf(
    "ν", means_vol, means_rf;
    ylabel="ν", solid_label="adjusted", y="ν", y2="ν_orig", ydomain=nothing, xscale="log"
  )

  # λ
  plot_by_vol_by_rf(
    "λ", means_vol, means_rf;
    ylabel="λ", solid_label="adjusted", y="λ", y2="λ_orig", ydomain=nothing, xscale="log"
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