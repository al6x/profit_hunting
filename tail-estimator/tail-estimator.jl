using Random, Statistics, StatsBase, Optim, Plots, Distributions, Extremes

includet.(["../lib/Lib.jl", "../lib/Report.jl"])
using .Lib, .Report

includet.("./lib.jl")

Report.configure!(report_path="tail-estimator/readme.md", asset_path="tail-estimator/readme",
  asset_url_path="readme");
default(dpi=200, titlefontsize = 10, markerstrokewidth = 0, legend=false, markersize=2,
  plot_titlefontsize=10);
Random.seed!(1);

report("""
  High precision estimator for Tail Exponent, Extreme Value Theory

  Run `julia evt/evt.jl`.

  # Goal

  Estimate tail exponent of `StudentT(ν) | ν ∈ [1.5, 10]` with high precision. Use case -
  estimate tails of stock log returns distribution, it's asymmetric and has tails similar
  to `StudentT`.

  # Problem

  Most POT estimators are biased, failing to estimate `ν` even on large 50k samples,
  having huge bias and variance.

  # Solution

  The combined estimater `ξ = 1/mean(1/DEDH.ξ, 1/HILL.ξ)` is better, with properly choosen
  treshold quantile `q >= 0.985` it has almost zero bias and small variance.

  I assume it works only for narrow case when tails are similar to `StudentT(ν)`, but that's
  exactly what we are interested in.

  # Experiment

  Data: 100 trials of `StudentT(ν=const)`, 20k sample each.

  Varius estimators used MLE, Weighted Moments, Hill, DEDH and DEDH-HILL.

  Various treshold quantiles `q ∈ [0.95, 0.995]` used to estimate the tail exponent. For each
  quantile bias and variance calculated across trials.

  The quantile used instead of explicit treshold to make estimation independent of the sample size.

  # Notes

  POT estimates full GPD, DEDH and HILL only the linear tail slope, so optimal quantile threshold
  is different.

  Another [study](https://www.bankofcanada.ca/wp-content/uploads/2019/08/swp2019-28.pdf) got similar
  results, huge errors for various estimators, one of authors is Laurens de Haan, pioneer of EVT and
  inventor of one of the best estimators "DEDH", so I assume they know what they are doing and
  numbers they got are reliable. They sampled StudentT with known ν and then estimated it
  [Table 1](docs/study1-table1.jpg) - huge errors, and it's the mean across many simulations, the
  errors for individual simulation is even larger.
""")

plot_cdf(x, d) = begin
  x = sort(x); n = length(x); px = (n:-1:1) ./ (n + 1)
  pd = max.(eps(), 1 .- cdf.(d, x))

  annotation=(0.005, 1e-3, text("ν=$(round(1/d.ξ, digits=1))"))

  p = plot(x, px; annotation, seriestype=:scatter, xscale=:log10, yscale=:log10, color=:blue,
    ylims = (1e-4, 1))
  plot!(p, x, pd; label="1 - CDF(model)", color=:red, lw=1)
  display(p)
end

plot_spagetti(ename; qs, trials, fit, ν_true, ssize) = begin
  νs = [last.(fit_q.(Ref(x), qs, Ref(fit))) for x in trials]
  n = length(νs)
  cols = [cgrad(:viridis)[t] for t in range(0, 1, length=n)]
  title = "$(ename) Spagetti (ν=$(ν_true), ssize=$(ssize))"

  yticks = [1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5, 6, 7, 8, 10]
  plt = plot(qs, νs[1];
    seriestype = :scatter, color = cols[1],
    xlab = "Quantile threshold", ylab = "ν", title,
    yscale = :log10, ylims = (1, 10),
    yticks = (yticks, string.(yticks))
  )

  plot!(qs, νs[1], color = cols[1], lw = 1.5, label = "")

  for i in 2:n
    plot!(qs, νs[i],
    seriestype = :scatter, color = cols[i], label = "")
    plot!(qs, νs[i], color = cols[i], lw = 1.0, label = "")
  end

  hline!([ν_true], color = :red, ls = :dash, label = "True ν = $ν_true")
  display(plt)
  save_asset(title, plt)
end;

plot_interval(ename; qs, trials, fit, ν_true, ssize) = begin
  νs = [last.(fit_q.(Ref(x), qs, Ref(fit))) for x in trials]

  nqs = length(qs)
  vals = qi -> getindex.(νs, qi)

  # IQR
  medns = [median(vals(qi))         for qi=1:nqs]
  q25s  = [quantile(vals(qi), 0.25) for qi=1:nqs]
  q75s  = [quantile(vals(qi), 0.75) for qi=1:nqs]

  # Relative Bias-Variance
  lmeans = [mean(log.(vals(qi))) for qi=1:nqs]
  lstdt  = [std(log.(vals(qi)))  for qi=1:nqs]
  bvs    = exp.(sqrt.((lmeans .- log(ν_true)) .^ 2 .+ lstdt .^ 2))

  # Plot
  ptitle = "$(ename) 25-50-75 IQR and Rel Bias-Variance (ν=$(ν_true), ssize=$(ssize))"
  yticks = [1, 1.25, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5, 6, 7, 8, 10]
  plt = plot(
    qs, medns; ribbon=(medns .- q25s, q75s .- medns), ylims = (1, 10),
    title=ptitle, fillalpha=0.1, color=:blue, label="q25-q75",
    xlab="Quantile threshold", ylab="ν",
    yscale = :log10,
    yticks = (yticks, string.(yticks))
  )
  plot!(qs, medns, color=:blue, lw=2, label="Median ν")
  hline!([ν_true], color = :red, ls = :dash, label = "True ν = $ν_true")

  # Add RMSE on right y-axis (gray line)
  plot!(qs, bvs; color=:gray, lw=2, label="Bias-Variance RMSE")

  display(plt)
  save_asset(ptitle, plt)
end

plot_log_log(ename; trials, q, fit, ν_true, ssize) = begin
  cols, xlims, ylims =3, (1e-3, 10), (1e-4, 1.0)
  zs, ds = unzip([fit_q(x, q, fit) for x in trials])
  title = "LogLog $(ename) q=$(q) (ν_true=$(ν_true), ssize=$(ssize))"

  m = length(zs); @assert m == length(ds)
  rows = ceil(Int, m / cols)

  plt = plot(layout=(rows, cols), size=(420*cols, 320*rows), plot_title=title)
  for j in 1:m
    x = sort(zs[j]); n = length(x)
    any(x .<= 0) && error("x must be positive for log–log scale")

    px = (n:-1:1) ./ (n + 1)
    # pd = max.(eps(), 1 .- cdf.(ds[j], x))
    annotation=(0.005, 1e-3, text("ν=$(round(1/ds[j].ξ, digits=1))"))

    plot!(plt, x, px; seriestype=:scatter, xscale=:log10, yscale=:log10, color=:blue, label="",
      subplot=j, xlims, ylims, annotation)
    # plot!(plt, x, pd; color=:red, lw=1, label="1 - CDF(model)", subplot=j)

    xm = LinRange(xlims[1], xlims[2], 400)
    pm = max.(eps(), 1 .- cdf.(ds[j], xm))
    plot!(plt, xm, pm; color=:red, lw=1, label="1 - CDF(model)", subplot=j)
  end

  display(plt)
  save_asset(title, plt)
end

# Run ----------------------------------------------------------------------------------------------
qs = range(0.98, 0.999, length=200);


# Estimators Comparison ----------------------------------------------------------------------------
ν_true, ssize = 3, 20_000
trials = [rand(TDist(ν_true), ssize) for _ in 1:100];

report("""
  # Estimators comparision (ν=$(ν_true), sample size=$(ssize), trials = $(length(trials)))

  IQR `25-50-75` and Relative Bias-Variance
  `exp(sqrt((mean(log(ν)) - log(ν_true))^2 + std(log(ν))^2))`.
""")

plot_intervals(;trials, qs, ssize, ν_true) = begin
  plot_interval("DEDH-HILL"; qs, trials, fit=(x -> 1/fit_gpd_dedh_hill(x).ξ), ν_true, ssize);
  plot_interval("DEDH"; qs, trials, fit=(x -> 1/fit_gpd_dedh(x).ξ), ν_true, ssize);
  plot_interval("HILL"; qs, trials, fit=(x -> 1/fit_gpd_hill(x).ξ), ν_true, ssize);
  plot_interval("GPD MLE"; qs, trials, fit=(x -> 1/fit_gpd_mle(x).ξ), ν_true, ssize);
  plot_interval("GPD WM"; qs, trials, fit=(x -> 1/fit_gpd_wm(x).ξ), ν_true, ssize);
end

plot_intervals(;trials, qs, ssize, ν_true);


# Spagetti Plot ------------------------------------------------------------------------------------
trials20 = trials[1:20]
report("""
  # Spagetti Plot (ν=$(ν_true), sample size=$(ssize), trials = $(length(trials)))

  Visual assessment of $(length(trials)) trials with various quantile tresholds, each trial is a
  separate line.
""")

plot_spagetti("DEDH-HILL"; qs, trials=trials20, fit=(x -> 1/fit_gpd_dedh_hill(x).ξ), ν_true, ssize);
plot_spagetti("DEDH"; qs, trials=trials20, fit=(x -> 1/fit_gpd_dedh(x).ξ), ν_true, ssize);
plot_spagetti("HILL"; qs, trials=trials20, fit=(x -> 1/fit_gpd_hill(x).ξ), ν_true, ssize);
plot_spagetti("MLE"; qs, trials=trials20, fit=(x -> 1/fit_gpd_mle(x).ξ), ν_true, ssize);
plot_spagetti("WM"; qs, trials=trials20, fit=(x -> 1/fit_gpd_wm(x).ξ), ν_true, ssize);


# Log Log ------------------------------------------------------------------------------------------
trials9 = trials[1:9]
best_q = 0.985
report("""
  # Log Log Plots

  Visual assessment of 9 trials with optimal quantile = $(best_q).
""")

plot_log_log("DEDH-HILL"; q=best_q, trials=trials9, fit=fit_gpd_dedh_hill, ν_true, ssize);
plot_log_log("DEDH"; q=best_q, trials=trials9, fit=fit_gpd_dedh, ν_true, ssize);
plot_log_log("HILL"; q=best_q, trials=trials9, fit=fit_gpd_hill, ν_true, ssize);
plot_log_log("MLE"; q=best_q, trials=trials9, fit=fit_gpd_mle, ν_true, ssize);
plot_log_log("WM"; q=best_q, trials=trials9, fit=fit_gpd_wm, ν_true, ssize);


# Varying ν ----------------------------------------------------------------------------------------
let
  for (name, fit) in [("DEDH-HILL", fit_gpd_dedh_hill), ("DEDH", fit_gpd_dedh)]
    report("
      # Stability of $name across ν and sample size
    ")
    for ssize in [5_000, 10_000, 20_000, 50_000, 300_000]
      report("**Sample size**=$(ssize)")
      for ν_true in [1.5, 5]
        trials = [rand(TDist(ν_true), ssize) for _ in 1:100];
        plot_interval(name; qs, trials, fit=(x -> 1/fit(x).ξ), ν_true, ssize);
      end
    end
  end
end
println("Done")