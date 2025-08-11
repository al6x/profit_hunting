using Random, Statistics, StatsBase, Optim, Plots, Distributions

includet.(["../lib/Lib.jl", "../lib/Report.jl"])
using .Lib, .Report

includet.("./plots.jl")

Report.configure!(report_path="evt/readme.md", asset_path="evt/readme", asset_url_path="readme");
Random.seed!(0);

report("""
  Correcting bias in EVT Peak Over Threshold (POT)

  **Problem**: POT is biased, it fails to estimate `StudenT(ν=4)` even on large 50k samples. Systematically
  underestimating the tail power ν.

  **Solution**: Use use weighted MLE estimator with higher weights on underestimated points to correct the bias.

  # Experiment

  Data: 100 trials of `StudentT(ν=4)`, each 20k sample.

  Various treshold quantiles `q ∈ [0.95, 0.995]` used to estimate the tail exponent, and for each quantile bias and
  variance calculated across 100 trials. The quantile used instead of explicit treshold to make estimation
  independent of the sample size.

  Then same repeated for "Weighted MLE" estimator, which boosts the weights of underestimated points.

  Only results for POT MLE estimator shown, there are also Weighted Moments and Bayesian estimators, I tested it, they
  are no better than MLE, same results.

  Run `julia evt/evt.jl`.
"""; print=false)

fit_gpd_mle(x; xi_min=1/8, xi_max=1/2.5, weights=nothing) = begin
  @assert all(x .>= 0) "Exceedances must be ≥ 0"
  n = length(x); @assert n > 0 "Empty data"

  nll(θ) = begin
    σ, ξ = θ
    (σ <= 0 || ξ < xi_min || ξ > xi_max) && return Inf
    d = GeneralizedPareto(0, σ, ξ)
    llhs = logpdf.(d, x)
    weights === nothing ? -sum(llhs) : -sum(weights .* llhs)
  end

  ξ0 = (xi_min + xi_max)/2
  σ0 = max(mean(x) * (1 - ξ0), eps())

  res = Optim.optimize(nll, [σ0, ξ0], Optim.BFGS(); autodiff = :forward)
  σ, ξ = Optim.converged(res) ? Optim.minimizer(res) : error("Can't estimate GPD MLE")
  GeneralizedPareto(0, σ, ξ)
end;

function fit_gpd_mle_weighted(x; n_tail, boost_underestimated_tail)
  x = sort(x); n = length(x)
  d0 = fit_gpd_mle(x)

  tail_idx = (n-n_tail+1):n
  S_emp = (n_tail:-1:1) ./ (n_tail + 1)
  S_mod = 1 .- cdf.(d0, x[tail_idx])
  underestimated_idx = tail_idx[S_emp .> S_mod]
  underestimated_n = length(underestimated_idx)

  weights = zeros(n) .+ 1/n
  if underestimated_n > 0
    weights[underestimated_idx] .*= boost_underestimated_tail
  end
  weights ./= sum(weights)
  fit_gpd_mle(x; weights=weights)
end;

estimate_q(x, q, estimate) = begin
  u = quantile(x, q)
  y = (x[x .> u] .- u) ./ u
  y, estimate(y)
end;

c_spagetti(ename, trials, estimate, ν_true) = begin
  νs = [last.(estimate_q.(Ref(x), qs, Ref(estimate))) for x in trials]
  plot_spagetti("POT $(ename) Spagetti"; ν_true=ν_true, qs=qs, νs=νs)
end;

c_interval(ename, trials, estimate, ν_true) = begin
  νs = [last.(estimate_q.(Ref(x), qs, Ref(estimate))) for x in trials]

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

c_log_log(ename, trials, q, estimate) = begin
  ys, ds = Lib.unzip([estimate_q(x, q, estimate) for x in trials])
  plot_cdfs("LogLog $(ename)", ys, ds)
end

# Run ----------------------------------------------------------------------------------------------
ν_true = 4
qs = range(0.97, 0.995, length = 50);
trials = [rand(TDist(ν_true), 20_000) for _ in 1:100];

report("""
  # Spagetti Plot

  Visual assessment of 10 trials with various quantile tresholds, each trial is a separate line.
""")

c_spagetti("MLE", trials[1:10], (x) -> 1/fit_gpd_mle(x).ξ, ν_true);
c_spagetti("Weighted MLE", trials[1:10], ((x) -> 1/fit_gpd_mle_weighted(x, n_tail=10, boost_underestimated_tail=1.4).ξ), ν_true);

report("""
  # Bias-Variance

  Inter quartile range (IQR) of the tail exponent ν across 100 trials for various quantile tresholds.
""")

c_interval("MLE", trials, ((x) -> 1/fit_gpd_mle(x).ξ), ν_true)
c_interval("Weighted MLE", trials, ((x) -> 1/fit_gpd_mle_weighted(x, n_tail=7, boost_underestimated_tail=1.4).ξ), ν_true);

best_q = 0.985
report("""
  # Log Log Plots

  Visual assessment of 9 trials with optimal quantile = $(best_q).
""")

c_log_log("MLE", trials[1:9], best_q, fit_gpd_mle);
c_log_log("Weighted MLE", trials[1:9], best_q, (x) -> fit_gpd_mle_weighted(x, n_tail=7, boost_underestimated_tail=1.4));

report("""
  # Checking if Weighted MLE also works for other ν = 3, 6
""")

for ν_true in [3, 6]
  trials = [rand(TDist(ν_true), 20_000) for _ in 1:100];
  c_interval("Weighted MLE ν=$(ν_true)", trials, ((x) -> 1/fit_gpd_mle_weighted(x, n_tail=7, boost_underestimated_tail=1.4).ξ), ν_true);
end