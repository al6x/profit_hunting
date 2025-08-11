import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy.stats import t
from pyextremes import plot_threshold_stability, plot_mean_residual_life
from pyextremes import get_extremes
from pyextremes import EVA

# 1. Generate 20,000 Student's t samples (df=4)
np.random.seed(42)
data = t(df=4).rvs(size=20_000)

# 2. Wrap in a time series (pyextremes requires timestamped series)
index = pd.date_range(start="2000-01-01", periods=len(data), freq="YS")
ts = pd.Series(data, index=index)

# 3. Plot to choose threshold (visual aids)
# plot_threshold_stability(ts, method="POT", thresholds=np.linspace(2, 6, 30))
# plt.show()

# plot_mean_residual_life(ts, thresholds=np.linspace(2, 6, 30))
# plt.show()

# # 4. Extract extremes above a threshold (e.g., 3.5)
# threshold = 3.5
# extremes = get_extremes(ts, method="POT", threshold=threshold)
model = EVA(ts)

model.get_extremes(method="BM", block_size="365.2425D")

model.fit_model()

# # 5. Fit Generalized Pareto Distribution (GPD) to extremes
# model = fit_model(extremes)

# # 6. Show parameter estimates
# print("GPD shape parameter (xi):", model.shape)
# print("GPD scale parameter (sigma):", model.scale)

# # 7. Plot fitted GPD over empirical tail
# model.plot_diagnostic()
# plt.show()
