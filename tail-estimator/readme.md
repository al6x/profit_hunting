High precision estimator for Tail Exponent, Extreme Value Theory

Run `julia evt/evt.jl`.

### Goal

Estimate tail exponent of `StudentT(ν) | ν ∈ [1.5, 10]` with high precision. Use case -
estimate tails of stock log returns distribution, it's asymmetric and has tails similar
to `StudentT`.

### Problem

Most POT estimators are biased, failing to estimate `ν` even on large 50k samples,
having huge bias and variance.

### Solution

The combined estimater `ξ = 1/mean(1/DEDH.ξ, 1/HILL.ξ)` is better, with properly choosen
treshold quantile `q >= 0.985` it has almost zero bias and small variance.

I assume it works only for narrow case when tails are similar to `StudentT(ν)`, but that's
exactly what we are interested in.

### Experiment

Data: 100 trials of `StudentT(ν=const)`, 20k sample each.

Varius estimators used MLE, Weighted Moments, Hill, DEDH and DEDH-HILL.

Various treshold quantiles `q ∈ [0.95, 0.995]` used to estimate the tail exponent. For each
quantile bias and variance calculated across trials.

The quantile used instead of explicit treshold to make estimation independent of the sample size.

### Notes

POT estimates full GPD, DEDH and HILL only the linear tail slope, so optimal quantile threshold
is different.

Another [study](https://www.bankofcanada.ca/wp-content/uploads/2019/08/swp2019-28.pdf) got similar
results, huge errors for various estimators, one of authors is Laurens de Haan, pioneer of EVT and
inventor of one of the best estimators "DEDH", so I assume they know what they are doing and
numbers they got are reliable. They sampled StudentT with known ν and then estimated it
[Table 1](docs/study1-table1.jpg) - huge errors, and it's the mean across many simulations, the
errors for individual simulation is even larger.

### Estimators comparision (ν=3, sample size=20000, trials = 100)

IQR `25-50-75` and Relative Bias-Variance
`exp(sqrt((mean(log(ν)) - log(ν_true))^2 + std(log(ν))^2))`.

DEDH-HILL 25-50-75 IQR and Rel Bias-Variance (ν=3, ssize=20000)

![DEDH-HILL 25-50-75 IQR and Rel Bias-Variance (ν=3, ssize=20000)](readme/dedh-hill-25-50-75-iqr-and-rel-bias-variance-3-ssize-20000.png)

DEDH 25-50-75 IQR and Rel Bias-Variance (ν=3, ssize=20000)

![DEDH 25-50-75 IQR and Rel Bias-Variance (ν=3, ssize=20000)](readme/dedh-25-50-75-iqr-and-rel-bias-variance-3-ssize-20000.png)

HILL 25-50-75 IQR and Rel Bias-Variance (ν=3, ssize=20000)

![HILL 25-50-75 IQR and Rel Bias-Variance (ν=3, ssize=20000)](readme/hill-25-50-75-iqr-and-rel-bias-variance-3-ssize-20000.png)

GPD MLE 25-50-75 IQR and Rel Bias-Variance (ν=3, ssize=20000)

![GPD MLE 25-50-75 IQR and Rel Bias-Variance (ν=3, ssize=20000)](readme/gpd-mle-25-50-75-iqr-and-rel-bias-variance-3-ssize-20000.png)

GPD WM 25-50-75 IQR and Rel Bias-Variance (ν=3, ssize=20000)

![GPD WM 25-50-75 IQR and Rel Bias-Variance (ν=3, ssize=20000)](readme/gpd-wm-25-50-75-iqr-and-rel-bias-variance-3-ssize-20000.png)

### Spagetti Plot (ν=3, sample size=20000, trials = 100)

Visual assessment of 100 trials with various quantile tresholds, each trial is a
separate line.

DEDH-HILL Spagetti (ν=3, ssize=20000)

![DEDH-HILL Spagetti (ν=3, ssize=20000)](readme/dedh-hill-spagetti-3-ssize-20000.png)

DEDH Spagetti (ν=3, ssize=20000)

![DEDH Spagetti (ν=3, ssize=20000)](readme/dedh-spagetti-3-ssize-20000.png)

HILL Spagetti (ν=3, ssize=20000)

![HILL Spagetti (ν=3, ssize=20000)](readme/hill-spagetti-3-ssize-20000.png)

MLE Spagetti (ν=3, ssize=20000)

![MLE Spagetti (ν=3, ssize=20000)](readme/mle-spagetti-3-ssize-20000.png)

WM Spagetti (ν=3, ssize=20000)

![WM Spagetti (ν=3, ssize=20000)](readme/wm-spagetti-3-ssize-20000.png)

### Log Log Plots

Visual assessment of 9 trials with optimal quantile = 0.985.

LogLog DEDH-HILL q=0.985 (ν_true=3, ssize=20000)

![LogLog DEDH-HILL q=0.985 (ν_true=3, ssize=20000)](readme/loglog-dedh-hill-q-0-985-true-3-ssize-20000.png)

LogLog DEDH q=0.985 (ν_true=3, ssize=20000)

![LogLog DEDH q=0.985 (ν_true=3, ssize=20000)](readme/loglog-dedh-q-0-985-true-3-ssize-20000.png)

LogLog HILL q=0.985 (ν_true=3, ssize=20000)

![LogLog HILL q=0.985 (ν_true=3, ssize=20000)](readme/loglog-hill-q-0-985-true-3-ssize-20000.png)

LogLog MLE q=0.985 (ν_true=3, ssize=20000)

![LogLog MLE q=0.985 (ν_true=3, ssize=20000)](readme/loglog-mle-q-0-985-true-3-ssize-20000.png)

LogLog WM q=0.985 (ν_true=3, ssize=20000)

![LogLog WM q=0.985 (ν_true=3, ssize=20000)](readme/loglog-wm-q-0-985-true-3-ssize-20000.png)


### Stability of DEDH-HILL across ν and sample size

**Sample size**=5000

DEDH-HILL 25-50-75 IQR and Rel Bias-Variance (ν=1.5, ssize=5000)

![DEDH-HILL 25-50-75 IQR and Rel Bias-Variance (ν=1.5, ssize=5000)](readme/dedh-hill-25-50-75-iqr-and-rel-bias-variance-1-5-ssize-5000.png)

DEDH-HILL 25-50-75 IQR and Rel Bias-Variance (ν=5.0, ssize=5000)

![DEDH-HILL 25-50-75 IQR and Rel Bias-Variance (ν=5.0, ssize=5000)](readme/dedh-hill-25-50-75-iqr-and-rel-bias-variance-5-0-ssize-5000.png)

**Sample size**=10000

DEDH-HILL 25-50-75 IQR and Rel Bias-Variance (ν=1.5, ssize=10000)

![DEDH-HILL 25-50-75 IQR and Rel Bias-Variance (ν=1.5, ssize=10000)](readme/dedh-hill-25-50-75-iqr-and-rel-bias-variance-1-5-ssize-10000.png)

DEDH-HILL 25-50-75 IQR and Rel Bias-Variance (ν=5.0, ssize=10000)

![DEDH-HILL 25-50-75 IQR and Rel Bias-Variance (ν=5.0, ssize=10000)](readme/dedh-hill-25-50-75-iqr-and-rel-bias-variance-5-0-ssize-10000.png)

**Sample size**=20000

DEDH-HILL 25-50-75 IQR and Rel Bias-Variance (ν=1.5, ssize=20000)

![DEDH-HILL 25-50-75 IQR and Rel Bias-Variance (ν=1.5, ssize=20000)](readme/dedh-hill-25-50-75-iqr-and-rel-bias-variance-1-5-ssize-20000.png)

DEDH-HILL 25-50-75 IQR and Rel Bias-Variance (ν=5.0, ssize=20000)

![DEDH-HILL 25-50-75 IQR and Rel Bias-Variance (ν=5.0, ssize=20000)](readme/dedh-hill-25-50-75-iqr-and-rel-bias-variance-5-0-ssize-20000.png)

**Sample size**=50000

DEDH-HILL 25-50-75 IQR and Rel Bias-Variance (ν=1.5, ssize=50000)

![DEDH-HILL 25-50-75 IQR and Rel Bias-Variance (ν=1.5, ssize=50000)](readme/dedh-hill-25-50-75-iqr-and-rel-bias-variance-1-5-ssize-50000.png)

DEDH-HILL 25-50-75 IQR and Rel Bias-Variance (ν=5.0, ssize=50000)

![DEDH-HILL 25-50-75 IQR and Rel Bias-Variance (ν=5.0, ssize=50000)](readme/dedh-hill-25-50-75-iqr-and-rel-bias-variance-5-0-ssize-50000.png)

**Sample size**=300000

DEDH-HILL 25-50-75 IQR and Rel Bias-Variance (ν=1.5, ssize=300000)

![DEDH-HILL 25-50-75 IQR and Rel Bias-Variance (ν=1.5, ssize=300000)](readme/dedh-hill-25-50-75-iqr-and-rel-bias-variance-1-5-ssize-300000.png)

DEDH-HILL 25-50-75 IQR and Rel Bias-Variance (ν=5.0, ssize=300000)

![DEDH-HILL 25-50-75 IQR and Rel Bias-Variance (ν=5.0, ssize=300000)](readme/dedh-hill-25-50-75-iqr-and-rel-bias-variance-5-0-ssize-300000.png)


### Stability of DEDH across ν and sample size

**Sample size**=5000

DEDH 25-50-75 IQR and Rel Bias-Variance (ν=1.5, ssize=5000)

![DEDH 25-50-75 IQR and Rel Bias-Variance (ν=1.5, ssize=5000)](readme/dedh-25-50-75-iqr-and-rel-bias-variance-1-5-ssize-5000.png)

DEDH 25-50-75 IQR and Rel Bias-Variance (ν=5.0, ssize=5000)

![DEDH 25-50-75 IQR and Rel Bias-Variance (ν=5.0, ssize=5000)](readme/dedh-25-50-75-iqr-and-rel-bias-variance-5-0-ssize-5000.png)

**Sample size**=10000

DEDH 25-50-75 IQR and Rel Bias-Variance (ν=1.5, ssize=10000)

![DEDH 25-50-75 IQR and Rel Bias-Variance (ν=1.5, ssize=10000)](readme/dedh-25-50-75-iqr-and-rel-bias-variance-1-5-ssize-10000.png)

DEDH 25-50-75 IQR and Rel Bias-Variance (ν=5.0, ssize=10000)

![DEDH 25-50-75 IQR and Rel Bias-Variance (ν=5.0, ssize=10000)](readme/dedh-25-50-75-iqr-and-rel-bias-variance-5-0-ssize-10000.png)

**Sample size**=20000

DEDH 25-50-75 IQR and Rel Bias-Variance (ν=1.5, ssize=20000)

![DEDH 25-50-75 IQR and Rel Bias-Variance (ν=1.5, ssize=20000)](readme/dedh-25-50-75-iqr-and-rel-bias-variance-1-5-ssize-20000.png)

DEDH 25-50-75 IQR and Rel Bias-Variance (ν=5.0, ssize=20000)

![DEDH 25-50-75 IQR and Rel Bias-Variance (ν=5.0, ssize=20000)](readme/dedh-25-50-75-iqr-and-rel-bias-variance-5-0-ssize-20000.png)

**Sample size**=50000

DEDH 25-50-75 IQR and Rel Bias-Variance (ν=1.5, ssize=50000)

![DEDH 25-50-75 IQR and Rel Bias-Variance (ν=1.5, ssize=50000)](readme/dedh-25-50-75-iqr-and-rel-bias-variance-1-5-ssize-50000.png)

DEDH 25-50-75 IQR and Rel Bias-Variance (ν=5.0, ssize=50000)

![DEDH 25-50-75 IQR and Rel Bias-Variance (ν=5.0, ssize=50000)](readme/dedh-25-50-75-iqr-and-rel-bias-variance-5-0-ssize-50000.png)

**Sample size**=300000

DEDH 25-50-75 IQR and Rel Bias-Variance (ν=1.5, ssize=300000)

![DEDH 25-50-75 IQR and Rel Bias-Variance (ν=1.5, ssize=300000)](readme/dedh-25-50-75-iqr-and-rel-bias-variance-1-5-ssize-300000.png)

DEDH 25-50-75 IQR and Rel Bias-Variance (ν=5.0, ssize=300000)

![DEDH 25-50-75 IQR and Rel Bias-Variance (ν=5.0, ssize=300000)](readme/dedh-25-50-75-iqr-and-rel-bias-variance-5-0-ssize-300000.png)

