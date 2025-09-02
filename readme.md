- Financial risk and uncertainty.
- Portfolio protection with put options.
- Bounded-loss option strategies.
- Financial statement analysis (Greenblatt).

[Stock Expected Return E[R]](mean)

![](mean/readme/mean-e-r-by-t-vol-and-t-rf-solid-adjusted.png)

[Stock Option Normalisation](option_norm)

![](option_norm/readme/norm-premium-p-e-r-scale-log-r-norm-strike-p-r-k-vol.png)

[Tails of Stock Returns](tail)

![](/tail/readme/tails-by-periods-x-period-y-color-type-dashed-model.png)

[High precision estimator for Tail Exponent, Extreme Value Theory](tail-estimator)

![](tail-estimator/readme/dedh-hill-25-50-75-iqr-and-rel-bias-variance-3-ssize-20000.png)

### TODO

- update pycall -> pythoncall
- Baker’s generalised asymmetric-t (GAT)
- AST — Asymmetric Student-t (Zhu & Galbraith, 2010).
- Finance: which stock option gives the highest return, under time-varying return profiles.
- left vs right tails exponent
- option_norm: rescale mmean plot as `(365/period)E[R]`.
- maybe add HoloViz https://panel.holoviz.org/reference/index.html (integrates with vscode and live update), streamlit, Pluto.jl

### Notes

- Julia-Python interop PythonCall.jl and juliacall