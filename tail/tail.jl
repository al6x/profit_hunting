using DataFrames, Random, Statistics, StatsBase, Optim, JSON, VegaLite

includet.(["../lib/Lib.jl", "../lib/Report.jl", "../lib/helpers.jl", "./plots.jl",
  "../tail-estimator/lib.jl"]);
using .Lib, .Report

Random.seed!(0);
Report.configure!(report_path="tail/readme.md", asset_path="tail/readme", asset_url_path="readme");

assign_quantiles!(ds, name) = begin
  ranks = ordinalrank(ds[!, name])
  q = (ranks .- 1) ./ (length(ds[!, name]) - 1)

  ds[!, "$(name)_q"] = q
  ds[!, "$(name)_dc"] = min.(floor.(Int, q .* 10) .+ 1, 10)
  ds[!, "$(name)_g5"] = min.(floor.(Int, q .* 5) .+ 1, 5)
  ds
end;

prepare_data_daily() = begin
  ds = cached("distr-prepare-data-daily") do
    df = pyimport("hist_data.data").load("hist_data/returns-daily.tsv.zip")
    DataFrame(df.reset_index(drop=true).to_dict(orient="list"))
  end

  ds.period = ds.period_d
  ds.lr = ds.lr_t2
  ds.lr_rf = ds.lr_rf_1y_t
  ds.hvol = ds.hscale_d_t
  ds.rsi = (ds.scalep_d_t .+ 1e-6) ./ (ds.scalen_d_t .+ 1e-6)
  ds
end;

prepare_data_periods() = begin
  ds = cached("distr-prepare-data-periods") do
    df = pyimport("hist_data.data").load("hist_data/returns-periods.tsv.zip")
    DataFrame(df.reset_index(drop=true).to_dict(orient="list"))
  end

  ds.period = ds.period_d
  ds.lr = ds.lr_t2
  ds.lr_rf = ds.lr_rf_1y_t
  ds.hvol = ds.hscale_d_t
  ds.rsi = (ds.scalep_d_t .+ 1e-6) ./ (ds.scalen_d_t .+ 1e-6)
  ds
end;

add_fields(ds) = begin
  ds = deepcopy(ds)
  vcat([begin
    # nvol
    min_by_sym = Dict(sg.symbol[1] => quantile(sg.hvol, 0.05) for sg in groupby(g, :symbol))
    min_hvol = [min_by_sym[sym] for sym in g.symbol]
    g.nvol = sqrt.(0.8 .* (g.scale_mad_d_t .^ 2) .+ 0.2 .* (max.(g.hvol, min_hvol) .^ 2))
    @assert all(g.nvol .> 0)

    assign_quantiles!(g, :vol)
    assign_quantiles!(g, :hvol)
    assign_quantiles!(g, :nvol)
    assign_quantiles!(g, :lr_rf)
    assign_quantiles!(g, :rsi)
    g
  end for g in groupby(ds, :period)]...)
end;

ds = let
  fields = [:lr, :vol, :hvol, :rsi, :lr_rf, :symbol, :t, :t2, :period, :cohort, :scale_mad_d_t]
  ds = vcat(prepare_data_daily()[!, fields], prepare_data_periods()[!, fields])
  add_fields(ds)
end;

# Optimal tail quantiles from `/tail-estimator`
optimal_tail_quantile(n) = max(0.985, 1 - 1000/n); # n > 100_000 ? 0.995 : 0.985;

# Final model for tail exponent, inferred from results of this experiment and
# external expert opinion.
ν_l_model(t) = 2.7 + 0.2352log(t);
ν_r_model(t) = 2.9 + 0.2352log(t);

empir_surv(x) = begin
  # Collapsing duplicates for better plot
  n      = length(x)
  cm     = countmap(x)
  x_uniq = sort(collect(keys(cm)); rev=true)
  counts = [cm[v] for v in x_uniq]
  y      = cumsum(counts) ./ n
  x_uniq, y
end;

# Tail should be normalised before declustering
decluster_tail(tail_ds, period) = begin
  window = Day(period == 1 ? 30 : round(Int, period*log(period)))

  # Declustering within same stock - keep only one max event in any 30d window.
  kept = vcat(
    (let
      g = sort(g, :lr, rev=true)
      n = nrow(g); keep = trues(n)
      for j in 1:n
        if keep[j]
          for k in (j+1):n
            if keep[k] && (abs(g.t2[j] - g.t2[k]) <= window)
              keep[k] = false
            end
          end
        end
      end
      g[keep, :]
    end
    for g in groupby(tail_ds, :symbol)
  )...)

  # Declustering across different stocks - keep only one max event for same t2 date.
  #
  # We are interested in tail per each stock, and correlated events across stocks
  # considered independent.
  #
  # kept = sort(kept, [:t2, :lr], rev=[false, true])
  # kept = combine(groupby(kept, :t2)) do df
  #   df[1, :]
  # end

  retained = nrow(kept)/nrow(tail_ds)
  @assert retained > 0.7 "Too much data lost in declustering: $((; period, retained))"

  kept.lr
end;

get_and_normalise_tail(ds; left) = begin
  x = left ? -ds.lr : ds.lr

  # Normalise, should be done before extracting tail
  x = (x .- mean(x)) ./ ds.nvol
  x = mscore(x) # optional

  # Tail threshold
  tq = optimal_tail_quantile(nrow(ds))
  u = quantile(x, tq)

  tail_mask = x .> u
  tail = x[tail_mask]
  tail_ds = deepcopy(ds[tail_mask, :])
  tail_ds.lr = tail

  # Decluster
  period = ds.period[1]
  tq, u, decluster_tail(tail_ds, period)
end;

calc_tail(tail; u, tq) = begin
  tailp = (1-tq) # Approximate, because of declustering

  # Estimate tail
  survx, survy = empir_surv(tail)
  survy .*= tailp
  survxn = (survx .- u ) ./ u

  # Fit GPD should use original tail without collapsed duplicates
  d = fit_gpd_dedh_hill((tail .- u) ./ u)

  # Estimated survival function for plotting
  survy_m = tailp .* ccdf.(Ref(d), survxn)
  ν = 1/d.ξ
  (; survx, survxn, survy, ν, survy_m)
end;


# Tails --------------------------------------------------------------------------------------------
group_by_period_cohort(op, ds) = begin
  DataFrame(combine(groupby(ds, [:period, :cohort])) do g
    period, cohort = g.period[1], g.cohort[1]
    results = op(g, period, cohort)
    spread((; period, cohort, results...))
  end)
end;

c_tail(calc, name, ds, ν_model) = begin
  by_cohort = group_by_period_cohort(calc, ds)

  plot_xyc_by(
    name, by_cohort; mark=:line_with_points,
    x="survxn", y="survy", y2="survy_m", by="period", detail="cohort",
    yscale="log", xscale="log",
    xdomain=(0.05, 30), ydomain=(2e-7, 0.015)
  );

  νs = by_cohort[:, [:period, :cohort, :ν]]
  νs = combine(groupby(νs, [:period, :cohort]),
    :ν => length => :tail_k, :ν => first => :ν
  );

  total = combine(groupby(νs, [:period]), :ν => median => :ν);
  total.ν = round.(total.ν, digits=1);
  total.ν_model = round.(ν_model.(total.period), digits=1);
  total_s = sprint(print, total);

  νs.ν = round.(νs.ν, digits=1);
  grouped_s = sprint(print, νs[νs.period .<= 365, :]);

  report("$name by periods")
  # plot_xyc_by(
  #   "$name by periods", total; mark=:line_with_points,
  #   x="period", y="ν", y2="ν_model", ydomain=(2, 8), xscale="log",# yscale="log",
  #   xdomain=(1, 1095),
  # );

  report_code(total_s)
  report_code(grouped_s)
  total
end;

Report.clear()
report(read("$(@__DIR__)/readme.t.md", String))

report("""
  # Tails of normalised log returns

  1d tails on chart start with lower probability because 1d has more data and higher treshold
  quantile.
""");

c_tail("Left Tail (Norm)", ds[ds.period .<= 60, :], ν_l_model) do g, _, _
  tq, u, tail = get_and_normalise_tail(g; left=true)
  calc_tail(tail; u, tq)
end

c_tail("Right Tail (Norm)", ds[ds.period .<= 60, :], ν_r_model) do g, _, _
  tq, u, tail = get_and_normalise_tail(g; left=false)
  calc_tail(tail; u, tq)
end


# Tails by key -------------------------------------------------------------------------------------
group_by_period_cohort_key(op, ds, key) = begin
  DataFrame(combine(groupby(ds, [:period, :cohort, key])) do g
    period, cohort, key_v = g.period[1], g.cohort[1], g[!, key][1]
    results = op(g, period, cohort, key_v)
    spread((; period, cohort, key=key_v, results...))
  end)
end;

c_tail_by_key(calc, name, ds, key) = begin
  by_key = group_by_period_cohort_key(calc, ds, key)

  plot_xyc_by(
    "$name raw", by_key;
    x="survx", y="survy", y2="survy_m", color=key, by="period", detail="cohort",
    yscale="log", xscale="log",
    xdomain=(3, 100), ydomain=(2e-6, 0.015)
  );

  plot_xyc_by(
    name, by_key;
    x="survxn", y="survy", y2="survy_m", color=key, by="period", detail="cohort",
    yscale="log", xscale="log",
    xdomain=(0.05, 30), ydomain=(2e-6, 0.015)
  );

  νs = by_key[:, [:period, :cohort, key, :ν]]
  νs = combine(groupby(νs, [:period, :cohort, key]),
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

# Tails by vol_dc ----------------------------------------------------------------------------------
report("# Tails by Vol");

c_tail_by_key("Left Tail by Vol (Norm)", ds[ds.period .<= 60, :], :nvol_dc) do g, _, _, _
  tq, u, tail = get_and_normalise_tail(g; left=true)
  calc_tail(tail; u, tq)
end;

c_tail_by_key("Right Tail by Vol (Norm)", ds[ds.period .<= 60, :], :nvol_dc) do g, _, _, _
  tq, u, tail = get_and_normalise_tail(g; left=false)
  calc_tail(tail; u, tq)
end


# Tails by rsi_dc ----------------------------------------------------------------------------------
report("# Tails by RSI");

c_tail_by_key("Left Tail by RSI (Norm)", ds[ds.period .<= 60, :], :rsi_dc) do g, _, _, _
  tq, u, tail = get_and_normalise_tail(g; left=true)
  calc_tail(tail; u, tq)
end;

c_tail_by_key("Right Tail by RSI (Norm)", ds[ds.period .<= 60, :], :rsi_dc) do g, _, _, _
  tq, u, tail = get_and_normalise_tail(g; left=false)
  calc_tail(tail; u, tq)
end

# Tails by vol, rf ---------------------------------------------------------------------------------
group_by_vol_rf(op, ds) = begin
  lr_rf_medns = Dict(g.lr_rf_g5[1] => median(g.lr_rf) for g in groupby(ds, :lr_rf_g5))
  DataFrame(combine(groupby(ds, [:nvol_dc, :lr_rf_g5])) do g
    nvol_dc, lr_rf_g5 = g.nvol_dc[1], g.lr_rf_g5[1]
    lr_rf_medn = lr_rf_medns[lr_rf_g5]
    spread((; nvol_dc, lr_rf_g5, lr_rf_medn, op(g)...))
  end)
end;

c_tail_by_vol_rf(calc, name, ds) = begin
  r = group_by_vol_rf(calc, ds);

  # plot_xyc_by(
  #   name, r;
  #   x="survxn", y="survy", y2="survy_m", color="nvol_dc", by="lr_rf_g5",
  #   yscale="log", xscale="log",
  #   xdomain=(0.05, 30), ydomain=(2e-6, 0.015)
  # );

  νs = combine(groupby(r, [:lr_rf_g5, :nvol_dc]),
    :ν => length => :tail_k, :ν => first => :ν, :lr_rf_medn => first => :lr_rf_medn
  );

  νs.ν = round.(νs.ν, digits=1);
  plot_xyc_by(
    "$name νs" , νs; x="lr_rf_medn", y="ν", color="nvol_dc", ydomain=(2, 6), yscale="log"
  );
end;

report("# Estimating tail by volatility and risk free rate")

c_tail_by_vol_rf("Left Tail by Vol, RF (Norm)", ds[ds.period .== 1, :]) do g
  tq, u, tail = get_and_normalise_tail(g; left=true)
  calc_tail(tail; u, tq)
end;

c_tail_by_vol_rf("Right Tail by Vol, RF (Norm)", ds[ds.period .== 1, :]) do g
  tq, u, tail = get_and_normalise_tail(g; left=false)
  calc_tail(tail; u, tq)
end;

# Tails for all periods ----------------------------------------------------------------------------
report("# Tails for all periods.");

let
  ltail = c_tail("Left Tail (Norm)", ds, ν_l_model) do g, _, _
    tq, u, tail = get_and_normalise_tail(g; left=true)
    calc_tail(tail; u, tq)
  end;

  rtail = c_tail("Right Tail (Norm)", ds, ν_r_model) do g, _, _
    tq, u, tail = get_and_normalise_tail(g; left=false)
    calc_tail(tail; u, tq)
  end;

  ltail.type .= "left"
  rtail.type .= "right"
  lrtail = vcat(ltail, rtail)

  plot_xyc_by(
    "Tails by periods", lrtail; mark=:line_with_points,
    x="period", y="ν", y2="ν_model", color="type", ydomain=(2, 8), xscale="log", xdomain=(1, 1095),
    scheme="magma"
  );
end

println("Done")