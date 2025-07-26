import Random, SpecialFunctions, StatsFuns

struct SkewT
  μ::Float64; σ::Float64; ν::Float64; λ::Float64
  a::Float64; b::Float64; c::Float64; kernelinvariant::Float64; logconst::Float64
end

function SkewT(μ::Float64, σ::Float64, ν::Float64, λ::Float64)
  # Precomputing constants
  c = SpecialFunctions.gamma((ν+1)/2) / (sqrt(π*(ν-2)) * SpecialFunctions.gamma(ν/2))
  a = 4λ*c * ((ν-2)/(ν-1))
  b = sqrt(1+3λ^2-a^2)
  kernelinvariant = 1/ (ν-2)
  logconst        = log(b)+log(c)

  SkewT(μ, σ, ν, λ, a, b, c, kernelinvariant, logconst)
end

# logkernel is faster than pdf for MLE
@inline function logkernel(d::SkewT, x::Float64)
  (; λ, ν, a, b, kernelinvariant) = d
  λsign = x < (-a/b) ? -1 : 1
  (-(ν + 1) / 2) * log1p(1/abs2(1+λ*λsign) * abs2(b*x + a) *kernelinvariant)
end

function pdf(d::SkewT, x::Float64)
  (; μ, σ, logconst) = d
  z = (x - μ) / σ
  logp = logkernel(d, z) - logconst
  exp(logp) / σ
end

function cdf(d::SkewT, x::Float64)
  (; μ, σ, ν, λ, a, b) = d
  z = (x - μ) / σ

  ypart = (b*z + a) * sqrt(ν/(ν - 2))
  y1, y2 = ypart/(1 - λ), ypart/(1 + λ)

  z < -a/b ?
    (1 - λ) * StatsFuns.tdistcdf(ν, y1) :
    (1 - λ)/2 + (1 + λ) * (StatsFuns.tdistcdf(ν, y2) - 0.5)
end

function quantile(d::SkewT, q::Float64)
  (; μ, σ, ν, λ, a, b) = d
  λconst = q < (1 - λ)/2 ? (1 - λ) : (1 + λ)
  quant_numer = q < (1 - λ)/2 ? q : (q + λ)
  z = 1/b * ((λconst) * sqrt((ν-2)/ν) * StatsFuns.tdistinvcdf(ν, quant_numer/λconst) - a)
  μ + σ*z
end

Random.rand(rng::Random.AbstractRNG, d::SkewT) = quantile(d, Random.rand(rng))