default(dpi=200)

function plot_spagetti(title; ν_true, qs::AbstractVector, νs::AbstractVector{<:AbstractVector})
  n = length(νs)
  cols = [cgrad(:viridis)[t] for t in range(0, 1, length=n)]

  plt = plot(qs, νs[1],
    seriestype = :scatter, markerstrokewidth = 0, color = cols[1],
    # label = label_first,
    xlab = "Quantile threshold", ylab = "ν",
    title = title,
    yscale = :log10, ylims = (2.5, 8),
    yticks = ([2, 2.5, 3, 3.5, 4, 4.5, 5, 6, 7, 8], string.([2, 2.5, 3, 3.5, 4, 4.5, 5, 6, 7, 8]))
  )

  plot!(qs, νs[1], color = cols[1], lw = 1.5, label = "")

  for i in 2:n
    plot!(qs, νs[i],
    seriestype = :scatter, markerstrokewidth = 0, color = cols[i], label = "")
    plot!(qs, νs[i], color = cols[i], lw = 1.0, label = "")
  end

  hline!([ν_true], color = :red, ls = :dash, label = "True ν = $ν_true")
  display(plt)
  save_asset(title, plt)
end