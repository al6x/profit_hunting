Estimating Tail Exponent

**Goal**: Estimate tail exponent of `StudentT(ν) | ν ∈ [1.5, 10]`. Real case - estimate tail
exponent of asymmetric distribution that has tails similar to `StudentT`.

**Problem**: POT is biased, it fails to estimate `ν` even on large 50k samples, systematically
underestimating it.

**Solution**: the `ξ = 1/mean(1/DEDH.ξ, 1/HILL.ξ)` is better, with properly choosen
treshold quantile `q = 0.985` it has almost zero bias and smaller variance.

### Experiment

Data: 100 trials of `StudentT(ν=const)`, 20k sample each.

Various treshold quantiles `q ∈ [0.95, 0.995]` used to estimate the tail exponent. For each
quantile bias and variance calculated across trials.

The quantile used instead of explicit treshold to make estimation independent of the sample size.

**Notes:**

POT estimates full GPD, DEDH and HILL only the linear tail slope, so optimal quantile threshold
is different.

Run `julia evt/evt.jl`.

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

