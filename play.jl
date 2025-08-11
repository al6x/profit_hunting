using Random, Distributions, Statistics, DataFrames, Plots
using SpecialFunctions: digamma

# parameters
Random.seed!(1)
mu = 0.005             # drift per 30d step
sigma = 0.08           # volatility per step
steps = 12 * 45 * 250  # number of 30d steps
S0 = 1.0               # initial price
ν = 3                  # degrees of freedom for Student-t (ν > 2)

p_tail(x) = begin
  tq, n = 0.01, length(x) # tail quantile
  nq = floor(Int, n * tq)

  x = sort(x)
  rtail = x[end-nq+1:end]

  rp = reverse((1:length(rtail)) ./ n)

  rtail, rp
end

function cdf_knn_entropy(x::Vector{Float64}; k::Int = 1)
  # Kozachenko–Leonenko entropy estimator
  x, n = sort(x), length(x)
  epsilons = similar(x)

  for i in 1:n
    left = i > k ? x[i] - x[i - k] : Inf
    right = i <= n - k ? x[i + k] - x[i] : Inf
    epsilons[i] = min(left, right)
  end

  return digamma(n) - digamma(k) + log(2) + mean(log.(epsilons .+ eps(eltype(x))))
end

function lrs360best(lps::Vector{Float64}; offsets=0:11, tailq=0.01)
  # construct offset window series
  shifted_samples = [
    [lps[i] - lps[i-12] for i in (13+offset):12:length(lps)]
    for offset in offsets
  ]

  # Estimating quantile on tail only
  # tqn = floor(Int, length(shifted_samples[1]) * tailq)
  # entropies = [cdf_knn_entropy(sort(lrs)[end-tqn:end]) for lrs in shifted_samples]
  # max_entropy_i = argmax(entropies)

  max_tail_i = argmax(maximum.(shifted_samples))

  shifted_samples[max_tail_i]
end

function lrs360avg(lps::Vector{Float64})
  # construct offset window series
  samples = [
    [lps[i] - lps[i-12] for i in (13+offset):12:length(lps)]
    for offset in 0:11
  ]
  samples = sort.(samples)
  n = minimum(length.(samples))

  [mean(s[i] for s in samples) for i in 1:n]
end


lps = cumsum(rand(TDist(ν), steps) .* sigma .+ mu)
lrs30   = [lps[i] - lps[i-1] for i in 2:length(lps)]
lrs360  = [lps[i] - lps[i-12] for i in 13:12:length(lps)]
lrs360o = [lps[i] - lps[i-12] for i in 13:length(lps)]
lrs360b = lrs360best(lps)
lrs_avg = lrs360avg(lps)

rtailo, rpo = p_tail(lrs360o)
rtail, rp = p_tail(lrs360)
rtailb, rpb = p_tail(lrs360b)
rtail_avg, rp_avg = p_tail(lrs_avg)

plt = plot(
  rtailo, rpo;
  # rtailc, rpc;
  xscale = :log10, yscale = :log10,
  label = "Overlapping",
  xlabel = "Return (log scale)", ylabel = "P(X ≥ x) (log scale)",
  legend = :topright, seriestype = :scatter,
  markersize = 2, markerstrokewidth = 0, color = :black,
)

plot!(
  rtail_avg, rp_avg;
  label = "Avg",
  seriestype = :scatter,
  markersize = 4,
  markerstrokewidth = 0
)

# for offset in 0:11
#   lrs360i = [lps[i] - lps[i-12] for i in (13+offset):12:length(lps)]
#   rtaili, rpi = p_tail(lrs360i)
#   plot!(
#     rtaili, rpi;
#     label = "Non Overlapping $(offset)",
#     seriestype = :scatter, markersize = 4, markerstrokewidth = 0
#   )
# end
# display(plt)

plot!(
  rtail, rp;
  label = "Non Overlapping",
  seriestype = :scatter,
  markersize = 4,
  markerstrokewidth = 0
)

# # plot!(
# #   rtailb, rpb;
# #   label = "Best Sample",
# #   seriestype = :scatter,
# #   markersize = 4,
# #   markerstrokewidth = 0
# # )