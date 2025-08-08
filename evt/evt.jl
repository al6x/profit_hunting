using Random, Statistics, StatsBase, Optim, Plots, Distributions, Extremes

includet.(["../lib/Lib.jl", "../lib/Report.jl"])
using .Lib, .Report

includet.("./plots.jl")

Report.configure!(report_path="evt/readme.md", asset_path="evt/readme", asset_url_path="readme")
Random.seed!(0)

report("""
  Measuring the precision of EVT Peak Over Threshold (POT) method.

  **Result**: out of the box it's no good at all, both bias and variance are high. It systematically underestimates the tail power ν, and very fragile slightest change in the treshold or sample produces wildly different results.

  # Experiment

  Use 100 trials of `StudentT(ν=4)` samples 20k size to estimate the tail power ν using the Peak Over Threshold (POT) method.

  Each sample estimated for various treshold quantile `q ∈ [0.95, 0.995]`.

  Only plots for MLE and Weighted Moments estimators shown, I also tested Bayesian it's no better.

  Run `julia evt/evt.jl`.
"""; print=false)

ν_true = 4

estimate_ν_mle(x) = 1/shape(gpfit(x))[1]
estimate_ν_wm(x)  = 1/shape(gpfitpwm(x))[1]
estimate_ν_bs(x)  = 1/shape(gpfitbayes(x))[1]

estimate_ν(x; qs, estimate) = [begin
  u = quantile(x, q)
  y = x[x .> u] .- u
  clamp(estimate(y), 2.5, 10)
end for q in qs]

qs = range(0.95, 0.995, length = 50)

c_spagetti(ename, estimate) = begin
  n_trials = 10
  νs = [begin
    x = rand(TDist(ν_true), 20_000)
    estimate_ν(x, qs=qs, estimate=estimate)
  end for _ in 1:n_trials]
  plot_spagetti("POT $(ename) Spagetti"; ν_true=ν_true, qs=qs, νs=νs)
end

report("""
# Spagetti Plot

Each line is separate trial.
""")
c_spagetti("MLE", estimate_ν_mle)
c_spagetti("WM", estimate_ν_wm)

c_interval(ename, estimate) = begin
  n_trials = 100
  νs = [begin
    x = rand(TDist(ν_true), 20_000)
    estimate_ν(x, qs=qs, estimate=estimate)
  end for _ in 1:n_trials]

  nqs = length(qs)
  vals = t -> getindex.(νs, t)

  # Means and std calculated in log space to compensate for the skewness of (2..4] vs [4..10)
  means = [exp.(mean(log.(vals(t)))) for t=1:nqs]
  stds  = [exp.(std(log.(vals(t))))  for t=1:nqs]
  q25s  = [quantile(vals(t), 0.25)  for t=1:nqs]
  q75s  = [quantile(vals(t), 0.75)  for t=1:nqs]

  # 25-75 IQR Plot
  ptitle = "POT $(ename) 25-75 IQR"
  plt = plot(
    qs, means; ribbon=(means .- q25s, q75s .- means), ylims = (2.5, 8),
    title=ptitle, fillalpha=0.1, color=:blue, label="q25-q75",
    xlab="Quantile threshold", ylab="ν",
    yscale = :log10,
    yticks = ([2, 2.5, 3, 3.5, 4, 4.5, 5, 6, 7, 8], string.([2, 2.5, 3, 3.5, 4, 4.5, 5, 6, 7, 8]))
  )
  plot!(qs, means, color=:blue, lw=2, label="Mean ν")
  hline!([ν_true], color = :red, ls = :dash, label = "True ν = $ν_true")
  display(plt)
  save_asset(ptitle, plt)

  # Bias-Variance Plot
  ptitle = "POT $(ename) Bias-Variance √ bias^2 + std^2"
  bvs = sqrt.((means .- ν_true).^2 .+ stds.^2)
  plt = plot(qs, bvs, title=ptitle, label=nothing,
    xlab="Quantile threshold", ylab = "Bias-Variance RMSE"
  )
  display(plt)
  save_asset("POT $(ename) Bias-Variance", plt)
end

report("""
# Bias-Variance
""")

c_interval("MLE", estimate_ν_mle)
c_interval("WM", estimate_ν_mle)

a=1