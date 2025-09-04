using DataFrames, Random, Statistics, StatsBase, Optim, Distributions, SpecialFunctions, KernelDensity, Plots

includet.(["../lib/Lib.jl", "../lib/Report.jl"]);
using .Lib, .Report

Random.seed!(0);
Report.configure!(report_path="variance/readme.md", asset_path="variance/readme", asset_url_path="readme");
default(dpi=200, titlefontsize = 10, markerstrokewidth = 0, legend=false, markersize=2,
  plot_titlefontsize=10);
Report.clear()

mean_abs_dev(d::TDist) = begin
  ν = d.ν
  ν <= 1 && return Inf
  2 * sqrt(ν) * gamma((ν + 1) / 2) / (sqrt(π) * (ν - 1) * gamma(ν / 2))
end;
mean_abs_dev(x::AbstractVector) = begin
  center = median(x)
  mean(abs.(x .- center))
end;

d = TDist(3.0);

# Distribution -------------------------------------------------------------------------------------
plot_distr(title, dvar, dmad; yscale = :linear) = begin
  ftitle = "$title $yscale"
  plt = plot(dvar.x, dvar.density; label="Var", color=:blue, xlabel="Estimated", ylabel="PDF",
    title=ftitle, xlim=(0, 20), ylim=(1e-4, 4), yscale);
  plot!(plt, dmad.x, dmad.density; label="MeanAbsDev", color=:orange)

  vline!(plt, [var(d)]; ls=:dash, color=:blue,   label="True Var")
  vline!(plt, [mean_abs_dev(d)]; ls=:dash, color=:orange, label="True MeanAbsDev")
  display(plt)
  save_asset(ftitle, plt)
end;

let
  report("# Convergence of Variance and Mean Absolute Deviation")
  n, n_trials = 100, 20_000;

  vars, mads = unzip(begin
    x = rand(d, n)
    mean(x .^2 ), mean(abs.(x))
  end for i in 1:n_trials);

  # KDEs
  dvar = kde(vars);
  dmad = kde(mads);
  title="Var vs MeanAbsDev $((; ν=d.ν, n, n_trials))";
  plot_distr(title, dvar, dmad);
  plot_distr(title, dvar, dmad; yscale = :log10);
end;

# Partial Convergence ------------------------------------------------------------------------------
partial_estimators(d::TDist, n::Int, trials::Int) = begin
  var_part = Vector{Vector{Float64}}(undef, trials)
  mad_part = Vector{Vector{Float64}}(undef, trials)
  for t in 1:trials
    x = rand(d, n)
    pv = Vector{Float64}(undef, n); pm = Vector{Float64}(undef, n)
    sum2 = 0.0; sum_abs = 0.0
    for i in 1:n
      xi = x[i]
      sum2 += xi^2
      sum_abs += abs(xi)
      pv[i] = sum2 / i
      pm[i] = sum_abs / i
    end
    var_part[t] = pv; mad_part[t] = pm
  end
  var_part, mad_part
end;

plot_partial(title, series, true_val) = begin
  n, n_trials = length(series[1]), length(series)
  plt = plot(1:n, series[1]; label="Trial 1", lw=1.6, palette=:tab10, xlabel="Sample n",
    ylabel="Estimated", title, legend=:topright, ylim=(0, 10))
  [plot!(plt, 1:n, series[t]; label="trial $t", lw=1.6) for t in 2:n_trials]
  hline!(plt, [true_val]; ls=:dash, label="True")
  display(plt)
  save_asset(title, plt)
end;

let
  report("# Partial Convergence of Variance and Mean Absolute Deviation")
  n, n_trials = 500, 10;
  var_part, mad_part = partial_estimators(d, n, n_trials);

  plot_partial("Partial Var $((; ν=d.ν))", var_part, var(d))
  plot_partial("Partial MeanAbsDev $((; ν=d.ν))", mad_part, mean_abs_dev(d))
end;