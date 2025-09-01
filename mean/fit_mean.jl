function target_mmeans(ds)
  report("""
  # Target for Model

    Target = E[R | period, volg, rfg]

  Problems:

  - Noise, skew, heavy tails - very hard to estimate mean.
  - Not enough data for longer periods >365d
  - Overlapping window of 30d introduces correlations for periods >30d
  - Estimating mean for {period, vol, rf} groups even harder because much less data, high volatility data severely
    distorted by noise.
  - Srises unevenly distributed over rf rate quantiles, direct fit makes no sense.

  Model fit in two steps, the target for model prepared - means estimated for `{period, vol, rf}` groups, with manual
  adjustments, then the model fit to match the target.

  Only two quantiles of rf rate used `rfg = 1,5` used, because other rf quantiles are heavily distorted
  by crises.

  To compensate for skipping rf rate quantiles, its means adjusted to match means of full quantiles
  `mean[(rfg = 1,5)^k] == mean[all 5 rf quantiles]` for each period. With additional constraint that means of
  higher volatility quantiles are not less than for lower volatility quantiles.

  Means for `period = 1095, rfg = 5` group lowered by ^0.8, because it looks too high and distorts model fitting.
  It's the longest period and has least data.
  """)

  # Estimating means by vol and rf quantiles
  # Leaving only 1 and 5 rf quantiles, because other are messed up and distort fitting.
  target = begin
    df15 = filter(:rfg => x -> x in (1, 5), ds)
    volg_medians = Dict(g.volg[1] => median(g.vol) for g in groupby(df15, :volg))
    rfg_medians  = Dict(g.rfg[1] => median(g.lr_rf) for g in groupby(df15, :rfg))
    combine(groupby(df15, [:period, :volg, :rfg])) do g
      period, volg, rfg = g.period[1], g.volg[1], g.rfg[1]
      vol, lr_rf = volg_medians[volg], rfg_medians[rfg]
      mmean = empir_mmean(g.lr)
      (; period, volg, rfg, mmean, vol, lr_rf)
    end
  end

  # But making its total mean same as all quantiles, to avoid biasing.
  target = begin
    mmeans_p = Dict(
      (g.period[1], g.volg[1]) => empir_mmean(g.lr)
      for g in groupby(ds, [:period, :volg])
    )

    # Adjust mmean per {period, vol} so `min L2 mean(target['period', 'vol']^k) - mean(mmeans_p['period', 'vol'])`
    sort!(target, [:period, :volg, :rfg])
    results = []
    for period_group in groupby(target, :period)
      previous_vol_mmeans = nothing
      for group in groupby(period_group, :volg)
        period, volg = group.period[1], group.volg[1]
        mmeans, target_mmean = group.mmean, mmeans_p[(period, volg)]

        # Reducing by K with constraint that mean for higher volg is not less than for lower volg
        transform(mmeans, K) = begin
          adjusted = mmeans .^ K
          if previous_vol_mmeans !== nothing
            adjusted = max.(adjusted, previous_vol_mmeans)
          end
          adjusted
        end

        res = optimize(
          (K) -> mean((transform(mmeans, K) .- target_mmean).^2),
          0.1, 10.0
        )
        K = Optim.converged(res) ? res.minimizer : error("Can't find K for period=$period, volg=$volg")

        adjusted = transform(mmeans, K)
        previous_vol_mmeans = adjusted
        push!(results, adjusted...)
      end
    end
    target.mmean = results
    target
  end

  # Lowering means for period = 1095, rfg = 5, it looks too high and distort model fitting
  begin
    mask = (target.period .== 1095) .& (target.rfg .== 5)
    target[mask, :mmean] .= target[mask, :mmean] .^ 0.8
  end

  target.nmmean .= norm_mean.(target.mmean, target.period)
  target
end

function fit_model(ds, target)
  report("""
  # Model

  Model linear in `lr_rf`

    Target = E[R | period, volg, rfg]

    Model =
      a = fn_a(period, vol, P)
      b = fn_b(period, vol, P)
      a + b lr_rf

    Model = E[R | period, vol, rf]
    E_hist[R] = exp(E[log R] + 0.5*Scale[log R]^2)
    E_pred[R]  = model(period, vol | P)
    P ~ min L2[weight (log E_pred[R] - log E_hist[R])]

  """)

  init = [0.04, 0.0364, 0.1409, 0.0349, -0.0221, 1.4357, -1.5853, -0.2642, 1.0113, -0.3498, -0.8414, 0, 0] # loss=0.8501 reg=0.0725

  # Fitting normalised mean works better than mean directly
  nmmean(period, vol, lr_rf, P) = begin
    np, nv = period / 365, vol / 0.015
    dv = P[6] - nv
    a = P[1] + P[2]*nv + P[3]/10*log(np) + P[4]/10*nv*np + P[5]*nv*log(np) + P[7]*dv^3
    # b = P[6] + P[7]*nv + P[8]*np + P[9]*nv*np^0.3 + P[10]/nv
    # a = P[1] + P[3]log(np) + P[5]nv + P[7]nv*log(np) + P[9]log(np)^2 + P[11]log(np)*nv^0.5
    # b = P[2] + P[4]log(np) + P[6]nv + P[8]nv*log(np) + P[10]log(np)^2 + P[12]log(np)*nv^0.5
    # Model should be linear in lr_rf to avoid overfitting
    return a #+ b*lr_rf
  end

  mmean(period, vol, lr_rf, P) = denorm_mean(nmmean(period, vol, lr_rf, P), period)

  reg(params) = 0.1 * mean(abs.(params) .^ 0.25)

  # Lover vol quantiles are more reliable and shorter periods have much more data because of overlapping window
  weights = 1 ./ target.vol ./ log.(target.period) / target.rfg .^4
  weights = weights ./ mean(weights)
  # target_v1rf1 = target[(target.volg .== 1) .& (target.rfg .== 1), :]
  # target_v5rf5 = target[(target.volg .== 5) .& (target.rfg .== 5), :]
  # softplus(x) = log1p(exp(x))

  loss(params) = begin
    # General fit
    preds = nmmean.(target.period, target.vol, target.lr_rf, Ref(params))
    errors = weights .* (preds .- target.nmmean) ./ target.nmmean
    # preds = mmean.(target.period, target.vol, target.lr_rf, Ref(params))
    # errors = weights .* (preds .- target.mmean) ./ target.mmean

    # # Penalty for overestimating vol5 rf5 or underestimating vol1 rf1
    # preds_v1rf1 = nmmean.(target_v1rf1.period, target_v1rf1.vol, target_v1rf1.lr_rf, Ref(params))
    # preds_v5rf5 = nmmean.(target_v5rf5.period, target_v5rf5.vol, target_v5rf5.lr_rf, Ref(params))
    # penalty = (
    #   mean(softplus.(preds_v5rf5 .- target_v5rf5.nmmean).^2) +
    #   mean(softplus.(target_v1rf1.nmmean .- preds_v1rf1).^2)
    # )/2

    return 100mean(errors .^ 2) # + reg(params) #+ penalty
  end

  inits = [randn(length(init)) for _ in 1:25]
  results = [optimize(loss, init, LBFGS()) for (i, init) in enumerate(inits)]
  converged = filter(Optim.converged, results)
  P = converged[findmin(res.minimum for res in converged)[2]].minimizer

  # res = optimize(loss, init, LBFGS())
  # P = Optim.converged(res) ? res.minimizer : error("Can't estimate P for mmeans")

  msg = "Found P=$(round.(P, digits=4)), loss=$(round(loss(P), digits=4)) reg=$(round(reg(P), digits=4))"
  report(msg); println(msg)

  (period, vol, lr_rf) -> mmean(period, vol, lr_rf, P)
end

function c_estimate_mmean(ds, mmean_)
  mmeans_vol_rf = group_by_vol_rf(ds; mmean_)
  mmeans_vol, mmeans_rf = group_by_vol(ds; mmean_), group_by_rf(ds; mmean_)

  plot_means(
    "Model Mean E[R]"; ylabel="E[R]", solid_label="model",
    means_vol_rf=mmeans_vol_rf, means_vol=mmeans_vol, means_rf=mmeans_rf
  )
end

function c_target_fitting(target, mmean_)
  target = deepcopy(target)
  target.mmean2 .= mmean_.(target.period, target.vol, target.lr_rf)
  target.nmmean2 .= norm_mean.(target.mmean2, target.period)

  plot_by_vol_rf(
    "Target Fitting E[R]", target;
    ylabel="E[R]", solid_label="fit"
  )
end

# target = target_mmeans(ds);
# mmean_ = fit_model(ds, target);
# c_target_fitting(target, mmean_);
# c_estimate_mmean(ds, mmean_);
