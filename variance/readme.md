Can variance of daily prices be measured with good precision?

Daily prices have tail exponent ~3, so so `Var[Var]` (4th moment) is infinity. So Var has
very slow convergence and can't be measured with good precision. Especially  on small samples,
so measures of current (point in time) volatility estimators are questionable.

And so GARCH, EMA and similar approaches relying on Var or STD are also questionable.

Yet, **I think this is not true**. Because stock prices have **conditional** variance (clusters of
volatility), not i.i.d. And so, the variance measurements are more reliable.

### Experiment

Measuring convergence of Variance and MeanAbsDev of i.i.d. `StudentT(ν=3)`, indeed it has slow convergence. But, it may not apply to real stock prices having conditional variance.

### Convergence of Variance and Mean Absolute Deviation

Var vs MeanAbsDev (ν = 3.0, n = 100, n_trials = 20000) linear

![Var vs MeanAbsDev (ν = 3.0, n = 100, n_trials = 20000) linear](readme/var-vs-meanabsdev-3-0-n-100-n-trials-20000-linear.png)

Var vs MeanAbsDev (ν = 3.0, n = 100, n_trials = 20000) log10

![Var vs MeanAbsDev (ν = 3.0, n = 100, n_trials = 20000) log10](readme/var-vs-meanabsdev-3-0-n-100-n-trials-20000-log10.png)

### Partial Convergence of Variance and Mean Absolute Deviation

Partial Var (ν = 3.0,)

![Partial Var (ν = 3.0,)](readme/partial-var-3-0.png)

Partial MeanAbsDev (ν = 3.0,)

![Partial MeanAbsDev (ν = 3.0,)](readme/partial-meanabsdev-3-0.png)

