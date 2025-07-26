include("./skewt.jl")

using Random, Test

# ARCHModels.StdSkewT used for test only, it doesn't have cdf, generic form and slower recalculating constants
# for every x.
import ARCHModels

function arch_skewt_pdf(μ, σ, ν, λ, x)
  d = ARCHModels.StdSkewT(ν, λ)
  z = (x - μ) / σ
  iv = ARCHModels.kernelinvariants(ARCHModels.StdSkewT, d.coefs)[1]
  logp = ARCHModels.logkernel(ARCHModels.StdSkewT, z, d.coefs, iv) - ARCHModels.logconst(ARCHModels.StdSkewT, d.coefs)
  exp(logp) / σ
end

@testset "SkewT.pdf" begin
  d = SkewT(1.0, 2.0, 3.0, 0.5)
  @test pdf(d, 0.1) ≈ arch_skewt_pdf(1.0, 2.0, 3.0, 0.5, 0.1)
end

@testset "SkewT.cdf,quantile" begin
  d = SkewT(1.0, 2.0, 3.0, 0.5)
  @test cdf(d, quantile(d, 0.1)) ≈ 0.1
end