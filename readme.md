- Financial risk and uncertainty.
- Portfolio protection with put options.
- Bounded-loss option strategies.
- Financial statement analysis (Greenblatt).

[Stock Expected Return E[R]](mean)

![Mean E[R] (x=lr_rf, y=adjusted, c=volg, dashed=original, by period)](mean/readme/mean-e-r-x-lr-rf-y-adjusted-c-volg-dashed-original-by-period.png)

[Stock Option Normalisation](option_norm)

![Norm Premium P/E[R]/Scale[log R], Norm Strike P(R < K | vol)](option_norm/readme/norm-premium-p-e-r-scale-log-r-norm-strike-p-r-k-vol.png)

[Estimting tails for stock log returns, Extreme Value Theory](tail)

![Left Tail by Vol Norm x=survxn, y=survycolor=vol_dc(cohort), dashed=survy_m by=period](/tail/readme/left-tail-by-vol-norm-x-survxn-y-survycolor-vol-dc-cohort-dashed-survy-m-by-period.png)

[Tail Estimator, Extreme Value Theory](tail-estimator)

![DEDH-HILL 25-50-75 IQR and Rel Bias-Variance (ν=3, ssize=20000)](tail-estimator/readme/dedh-hill-25-50-75-iqr-and-rel-bias-variance-3-ssize-20000.png)

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