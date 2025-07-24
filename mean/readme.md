Estimating expected stock return E[R] from historical data.

[add top image]

Run `julia mean/mean.jl`.

### Exploring Mean E[R]

Simulated bankrupts added, details `../hist_data/readme.md`.

Vol deciles 9,10 are visibly distorted, suppressing mean to make it look visibly same as 1-8 deciles. Mean suppressed
as `log(r)^k(period, vol_dc) for vol_dc in 9, 10`. It distorts the distribution shape, but ok for mean.

Limiting mean to once in 10y events. Truncating upper tail by 1/3650 quantile. Because of positive skewed heavy tails
mean is very sensitive to positive rare events, large event once in 100 year event may influence mean. Strictly
speaking the true mean should account for once in 100 y events, so our estimation is not true mean. The 10y treshold
also looks to be good as it's has almost no effect on the observable mean.

![Mean E[R] by (T, vol) and (T, rf), (solid - adjusted)](readme/mean-e-r-by-t-vol-and-t-rf-solid-adjusted.png)

![Norm E[R] by (T, vol) and (T, rf), (solid - adjusted)](readme/norm-e-r-by-t-vol-and-t-rf-solid-adjusted.png)

![Mean E[R] (x=lr_rf, y=adjusted, c=volg, dashed=original, by period)](readme/mean-e-r-x-lr-rf-y-adjusted-c-volg-dashed-original-by-period.png)

![Norm Mean (365/period)log(E[R]) (x=lr_rf, y=nadjusted, c=volg, dashed=noriginal, by period)](readme/norm-mean-365-period-log-e-r-x-lr-rf-y-nadjusted-c-volg-dashed-noriginal-by-period.png)

![Mean E[R] (x=vol, y=adjusted, c=rfg, dashed=original, by period)](readme/mean-e-r-x-vol-y-adjusted-c-rfg-dashed-original-by-period.png)

![Norm Mean (365/period)log(E[R]) (x=vol, y=nadjusted, c=rfg, dashed=noriginal, by period)](readme/norm-mean-365-period-log-e-r-x-vol-y-nadjusted-c-rfg-dashed-noriginal-by-period.png)

### Exploring Log Mean E[log R] with 5 rf groups

![Log Mean E[log R] by (T, vol) and (T, rf), (solid - adjusted)](readme/log-mean-e-log-r-by-t-vol-and-t-rf-solid-adjusted.png)

![Norm Log Mean (365/period)(E[log R]) by (T, vol) and (T, rf), (solid - adjusted)](readme/norm-log-mean-365-period-e-log-r-by-t-vol-and-t-rf-solid-adjusted.png)

![Log Mean E[log R] (x=lr_rf, y=adjusted, c=volg, dashed=original, by period)](readme/log-mean-e-log-r-x-lr-rf-y-adjusted-c-volg-dashed-original-by-period.png)

![Norm Log Mean (365/period)E[log R] (x=lr_rf, y=nadjusted, c=volg, dashed=noriginal, by period)](readme/norm-log-mean-365-period-e-log-r-x-lr-rf-y-nadjusted-c-volg-dashed-noriginal-by-period.png)

![Log Mean E[log R] (x=vol, y=adjusted, c=rfg, dashed=original, by period)](readme/log-mean-e-log-r-x-vol-y-adjusted-c-rfg-dashed-original-by-period.png)

![Norm Log Mean (365/period)E[log R] (x=vol, y=nadjusted, c=rfg, dashed=noriginal, by period)](readme/norm-log-mean-365-period-e-log-r-x-vol-y-nadjusted-c-rfg-dashed-noriginal-by-period.png)

### Exploring Log Mean E[log R] with 10 rf groups

![Log Mean E[log R] by (T, vol) and (T, rf), (solid - adjusted)](readme/log-mean-e-log-r-by-t-vol-and-t-rf-solid-adjusted.png)

![Norm Log Mean (365/period)(E[log R]) by (T, vol) and (T, rf), (solid - adjusted)](readme/norm-log-mean-365-period-e-log-r-by-t-vol-and-t-rf-solid-adjusted.png)

![Log Mean E[log R] (x=lr_rf, y=adjusted, c=volg, dashed=original, by period)](readme/log-mean-e-log-r-x-lr-rf-y-adjusted-c-volg-dashed-original-by-period.png)

![Norm Log Mean (365/period)E[log R] (x=lr_rf, y=nadjusted, c=volg, dashed=noriginal, by period)](readme/norm-log-mean-365-period-e-log-r-x-lr-rf-y-nadjusted-c-volg-dashed-noriginal-by-period.png)

![Log Mean E[log R] (x=vol, y=adjusted, c=rfg, dashed=original, by period)](readme/log-mean-e-log-r-x-vol-y-adjusted-c-rfg-dashed-original-by-period.png)

![Norm Log Mean (365/period)E[log R] (x=vol, y=nadjusted, c=rfg, dashed=noriginal, by period)](readme/norm-log-mean-365-period-e-log-r-x-vol-y-nadjusted-c-rfg-dashed-noriginal-by-period.png)

### Data

Details `../hist_data/readme.md`.

    - volg - volatility group
    - rfg - risk free rate group

