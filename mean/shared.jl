includet.(["../lib/Lib.jl", "../lib/Report.jl", "../lib/helpers.jl", "./plots.jl"])

using DataFrames, Random, Statistics, StatsBase, Optim
using .Lib, .Report

begin
  # Config

  plots_py = pyimport("mean.plots")

  Random.seed!(0)
  Report.configure!(report_path="mean/readme.md", asset_path="mean/readme", asset_url_path="readme")
  py"""
  from lib.helpers import configure_report
  configure_report(report_path="mean/readme.md", asset_path="mean/readme", asset_url_path='readme')
  """
end

function group_by_vol_rf(ds, ops; volg=:vol_dc, rfg=:rfg)
  volg_medians = Dict(g[!, volg][1] => median(g.vol) for g in groupby(ds, volg))
  rfg_medians = Dict(g[!, rfg][1] => median(g.lr_rf) for g in groupby(ds, rfg))

  rows = combine(groupby(ds, [:period, volg, rfg])) do g
    period, volg_v, rfg_v = g.period[1], g[!, volg][1], g[!, rfg][1]
    vol, lr_rf = volg_medians[volg_v], rfg_medians[rfg_v]
    results = (; (k => op(g) for (k, op) in pairs(ops))...)
    merge((; period, volg=volg_v, rfg=rfg_v, vol, lr_rf), results)
  end

  DataFrame(rows)
end

function group_by_vol(ds, ops; volg=:vol_dc)
  lr_rf_median = median(ds.lr_rf)

  rows = combine(groupby(ds, [:period, volg])) do g
    period, volg_v = g.period[1], g[!, volg][1]
    vol, lr_rf  = median(g.vol), lr_rf_median
    results = (; (k => op(g) for (k, op) in pairs(ops))...)
    merge((; period, volg=volg_v, vol, lr_rf), results)
  end

  DataFrame(rows)
end

function group_by_rf(ds, ops; rfg=:rfg)
  vol_median = median(ds.vol)

  rows = combine(groupby(ds, [:period, rfg])) do g
    period, rfg_v = g.period[1], g[!, rfg][1]
    vol, lr_rf = vol_median, median(g.lr_rf)
    results = (; (k => op(g) for (k, op) in pairs(ops))...)
    # mmean  = empir_mmean(g.lr)
    # mmean2 = isnothing(model) ? nothing : mean(model.(Ref(period), g.vol, g.lr_rf))
    merge((; period, rfg=rfg_v, vol, lr_rf), results)
  end

  DataFrame(rows)
end

function prepare_data()
  ds = cached("mean-prepare-data") do
    df = pyimport("hist_data.data").load_with_bankrupts()
    DataFrame(df.reset_index(drop=true).to_dict(orient="list"))
  end

  function assign_rf_quantiles!(ds)
    ranks = ordinalrank(ds.lr_rf)
    q = (ranks .- 1) ./ (length(ds.lr_rf) - 1)

    ds.rf_q = q
    ds.rf_dc = min.(floor.(q .* 10) .+ 1, 10)
    ds.rf_g5 = min.(floor.(q .* 5) .+ 1, 5)
    ds.rf_g4 = min.(floor.(q .* 4) .+ 1, 4)
    ds.rf_g3 = min.(floor.(q .* 3) .+ 1, 3)
    ds.rfg = ds.rf_g5 #min.(floor.(q .* 5) .+ 1, 5)
    ds
  end

  ds.period = ds.period_d
  ds.lr = ds.lr_t2
  ds.lr_rf = ds.lr_rf_1y_t
  assign_rf_quantiles!(ds)
  ds.volg = (ds.vol_dc .+ 1) .÷ 2

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

function truncate_ds(ds, tq)
  combine(groupby(ds, :volg)) do g
    max = quantile(g.lr, tq)
    filter(:lr => x -> x <= max, g)
  end
end
