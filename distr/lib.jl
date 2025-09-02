group_by_vol_rf(ds, op; volg=:vol_dc, rfg=:rfg) = begin
  volg_medians = Dict(g[!, volg][1] => median(g.vol) for g in groupby(ds, volg))
  rfg_medians = Dict(g[!, rfg][1] => median(g.lr_rf) for g in groupby(ds, rfg))

  rows = combine(groupby(ds, [:period, volg, rfg])) do g
    period, volg_v, rfg_v = g.period[1], g[!, volg][1], g[!, rfg][1]
    vol, lr_rf = volg_medians[volg_v], rfg_medians[rfg_v]
    results = op(g)
    spread(merge((; period, volg=volg_v, rfg=rfg_v, vol, lr_rf), results))
  end

  DataFrame(rows)
end

function group_by_vol(ds, op; volg=:vol_dc)
  lr_rf_median = median(ds.lr_rf)

  rows = combine(groupby(ds, [:period, volg])) do g
    period, volg_v = g.period[1], g[!, volg][1]
    vol, lr_rf  = median(g.vol), lr_rf_median
    results = op(g)
    spread(merge((; period, volg=volg_v, vol, lr_rf), results))
  end

  DataFrame(rows)
end

function group_by_vol_cohort(ds, op; volg=:vol_dc)
  lr_rf_median = median(ds.lr_rf)

  rows = combine(groupby(ds, [:period, volg, :cohort])) do g
    period, volg_v, cohort = g.period[1], g[!, volg][1], g.cohort[1]
    vol, lr_rf = median(g.vol), lr_rf_median
    results = op(g, period, volg_v, cohort)
    spread(merge((; period, cohort, volg=volg_v, vol, lr_rf), results))
  end

  DataFrame(rows)
end

function group_by_rf(ds, op; rfg=:rfg)
  vol_median = median(ds.vol)

  rows = combine(groupby(ds, [:period, rfg])) do g
    period, rfg_v = g.period[1], g[!, rfg][1]
    vol, lr_rf = vol_median, median(g.lr_rf)
    results = op(g)
    spread(merge((; period, rfg=rfg_v, vol, lr_rf), results))
  end

  DataFrame(rows)
end

function assign_rf_quantiles!(ds)
  ranks = ordinalrank(ds.lr_rf)
  q = (ranks .- 1) ./ (length(ds.lr_rf) - 1)

  ds.rf_q = q
  ds.rf_dc = min.(floor.(Int, q .* 10) .+ 1, 10)
  ds.rf_g5 = min.(floor.(Int, q .* 5) .+ 1, 5)
  ds.rf_g4 = min.(floor.(Int, q .* 4) .+ 1, 4)
  ds.rf_g3 = min.(floor.(Int, q .* 3) .+ 1, 3)
  ds.rfg = ds.rf_g5 #min.(floor.(q .* 5) .+ 1, 5)
  ds
end

function assign_quantiles!(ds, name)
  ranks = ordinalrank(ds[!, name])
  q = (ranks .- 1) ./ (length(ds[!, name]) - 1)

  ds[!, "$(name)_q"] = q
  ds[!, "$(name)_dc"] = min.(floor.(Int, q .* 10) .+ 1, 10)
  ds
end

function prepare_data_daily()
  ds = cached("distr-prepare-data-daily") do
    df = pyimport("hist_data.data").load("hist_data/returns-daily.tsv")
    DataFrame(df.reset_index(drop=true).to_dict(orient="list"))
  end

  ds.period = ds.period_d
  ds.lr = ds.lr_t2
  ds.lr_rf = ds.lr_rf_1y_t
  assign_rf_quantiles!(ds)
  ds.volg = (ds.vol_dc .+ 1) .÷ 2

  # Not really RSI just something to group in RSI like manner
  error("fix rsi for 1d")
  ds.rsi = ds.lr_t ./ (ds.hscale_d_t .+ 1e-6)


  assign_quantiles!(ds, :rsi)

  ds
end

function prepare_data()
  ds = cached("distr-prepare-data-periods") do
    df = pyimport("hist_data.data").load("hist_data/returns-periods.tsv")
    DataFrame(df.reset_index(drop=true).to_dict(orient="list"))
  end

  ds.period = ds.period_d
  ds.lr = ds.lr_t2
  ds.lr_rf = ds.lr_rf_1y_t
  assign_rf_quantiles!(ds)
  ds.volg = (ds.vol_dc .+ 1) .÷ 2

  ds.rsi = (ds.scalep_d_t .+ 1e-6) ./ (ds.scalen_d_t .+ 1e-6)
  assign_quantiles!(ds, :rsi)

  ds
end

function adjust_data_lr!(ds)
  # Adjusting means of vol9 and vol10, it distorts the distribution shape but ok for mean.
  adjustments = [
    # vol10
    (10, 30,   0.95),
    (10, 60,   0.85),
    (10, 91,   0.76),
    (10, 182,  0.68),
    (10, 365,  0.68),
    (10, 730,  0.74),
    (10, 1095, 0.75),
    # vol9
    (9,  30,   0.98),
    (9,  60,   0.93),
    (9,  91,   0.96),
    (9,  182,  0.97),
    (9,  365,  0.93),
    (9,  730,  0.93),
    (9,  1095, 0.95),
  ]
  for (vol_dc, period, factor) in adjustments
    mask = (ds.period .== period) .& (ds.vol_dc .== vol_dc)
    ds[mask, :lr] .= ds[mask, :lr] .* factor
  end
end

function truncate_by_period_volg_cohort(ds, tq)
  combine(groupby(ds, [:period, :volg, :cohort])) do g
    period = g.period[1]
    min = quantile(g.lr, tq(period))
    max = quantile(g.lr, 1-tq(period))
    filter(:lr => x -> min <= x <= max , g)
  end
end
