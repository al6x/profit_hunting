using Distributions

gpd_tail(x, q) = begin
  u = quantile(x, q)
  (x[x .> u] .- u) ./ u
end

fit_q(x, q, fit) = begin
  z = gpd_tail(x, q)
  z, fit(z)
end


fit_gpd_hill(z; ξ_min=1/10, ξ_max=1/1) = begin
  @assert !isempty(z) && all(z .>= 0)
  ξ = mean(log1p.(z))
  ξ = clamp(ξ, ξ_min, ξ_max)
  σ = max(mean(z) * (1 - ξ), 1e-6)
  GeneralizedPareto(0, σ, ξ)
end


fit_gpd_dedh(z; ξ_min=1/10, ξ_max=1/1) = begin
  @assert !isempty(z) && all(z .>= 0)
  t = log1p.(z)
  m1 = mean(t); m2 = mean(t.^2)
  denom = 1 - (m1^2 / m2)
  ξ = (denom <= 0 || !isfinite(denom)) ? m1 : (m1 + 1 - 0.5/denom)  # fallback to Hill if degenerate
  ξ = clamp(ξ, ξ_min, ξ_max)
  σ = max(mean(z) * (1 - ξ), 1e-6)
  GeneralizedPareto(0, σ, ξ)
end


fit_gpd_dedh_hill(z; ξ_min=1/10, ξ_max=1/1) = begin
  dedh, hill = fit_gpd_dedh(z; ξ_min, ξ_max), fit_gpd_hill(z; ξ_min, ξ_max)
  ξ = 1 / ((1/dedh.ξ + 1/hill.ξ) / 2)
  ξ = clamp(ξ, ξ_min, ξ_max)
  σ = max(mean(z) * (1 - ξ), 1e-6)
  GeneralizedPareto(0, σ, ξ)
end


fit_gpd_mle(z; ξ_min=1/10, ξ_max=1/1, weights=nothing) = begin
  @assert !isempty(z) && all(z .>= 0)
  n = length(z); @assert n > 0 "Empty data"

  nll(θ) = begin; σ, ξ = θ
    (σ <= 0 || ξ < ξ_min || ξ > ξ_max) && return Inf
    d = GeneralizedPareto(0, σ, ξ)
    llhs = logpdf.(d, z)
    weights === nothing ? -sum(llhs) : -sum(weights .* llhs)
  end

  ξ0 = (ξ_min + ξ_max)/2
  σ0 = max(mean(z) * (1 - ξ0), eps())

  res = Optim.optimize(nll, [σ0, ξ0], Optim.BFGS(); autodiff = :forward)
  σ, ξ = Optim.converged(res) ? Optim.minimizer(res) : error("Can't fit GPD MLE")
  ξ = clamp(ξ, ξ_min, ξ_max)
  GeneralizedPareto(0, σ, ξ)
end


fit_gpd_mle_weighted(z; n_tail=5, boost_underestimated_tail=1.4) = begin
  @assert !isempty(z) && all(z .>= 0)
  z = sort(z); n = length(z)
  d0 = fit_gpd_mle(z)

  tail_idx = (n-n_tail+1):n
  S_emp = (n_tail:-1:1) ./ (n_tail + 1)
  S_mod = 1 .- cdf.(d0, z[tail_idx])
  underestimated_idx = tail_idx[S_emp .> S_mod]
  underestimated_n = length(underestimated_idx)

  weights = zeros(n) .+ 1/n
  if underestimated_n > 0
    weights[underestimated_idx] .*= boost_underestimated_tail
  end
  weights ./= sum(weights)
  fit_gpd_mle(z; weights=weights)
end


# Very slightly better than `fit_gpd_mle`.
fit_gpd_wm(z; ξ_min=1/10, ξ_max=1/1) = begin
  @assert !isempty(z) && all(z .>= 0)
  r = gpfitpwm(z)
  ξ = clamp(shape(r)[1], ξ_min, ξ_max); σ = scale(r)[1]
  GeneralizedPareto(0, σ, ξ)
end


# No effect, same as `fit_gpd_mle(x)`
fit_trunc(z; trunc=3, fit) = begin
  @assert !isempty(z) && all(z .>= 0)
  z = sort(z)
  ds = [fit(z[1:end-i]) for i in 0:trunc]
  ds[argmax(getproperty.(ds, :ξ))]  # Return the model with the highest tail exponent
end;