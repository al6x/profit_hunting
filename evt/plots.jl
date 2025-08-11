default(dpi=200, titlefontsize = 10, markerstrokewidth = 0, legend=false, markersize=2, plot_titlefontsize=10)


function plot_spagetti(title; ν_true, qs::AbstractVector, νs::AbstractVector{<:AbstractVector})
  n = length(νs)
  cols = [cgrad(:viridis)[t] for t in range(0, 1, length=n)]

  plt = plot(qs, νs[1],
    seriestype = :scatter, color = cols[1],
    xlab = "Quantile threshold", ylab = "ν", title = title,
    yscale = :log10, ylims = (2.5, 8),
    yticks = ([2, 2.5, 3, 3.5, 4, 4.5, 5, 6, 7, 8], string.([2, 2.5, 3, 3.5, 4, 4.5, 5, 6, 7, 8]))
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
end


function plot_cdfs(title, xs, ds; cols::Int=3, xlims=(1e-3, 10), ylims=(1e-4, 1.0))
  m = length(xs); @assert m == length(ds)
  rows = ceil(Int, m / cols)

  plt = plot(layout=(rows, cols), size=(420*cols, 320*rows), plot_title=title)
  for j in 1:m
    x = sort(xs[j]); n = length(x)
    any(x .<= 0) && error("x must be positive for log–log scale")

    px = (n:-1:1) ./ (n + 1)
    # pd = max.(eps(), 1 .- cdf.(ds[j], x))
    annotation=(0.005, 1e-3, text("ν=$(round(1/ds[j].ξ, digits=1))"))

    plot!(plt, x, px; seriestype=:scatter, xscale=:log10, yscale=:log10, color=:blue, label="", subplot=j, xlims, ylims, annotation)
    # plot!(plt, x, pd; color=:red, lw=1, label="1 - CDF(model)", subplot=j)

    xm = LinRange(xlims[1], xlims[2], 400)
    pm = max.(eps(), 1 .- cdf.(ds[j], xm))
    plot!(plt, xm, pm; color=:red, lw=1, label="1 - CDF(model)", subplot=j)
  end

  display(plt)
  save_asset(title, plt)
end