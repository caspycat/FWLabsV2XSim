# Controlled density regression

This regression isolates offered load from the ETSI traffic-model operating
points. Within each technology's three-point sweep, it holds the 2.1 km road,
three lanes per direction, lane width, 140 km/h speed, zero speed variation,
periodic packet generation, channel configuration, and allocator
configuration fixed. Only the vehicle count changes: 72, 126, and 252
vehicles.

The default manifest runs LTE-V2X, NR-V2X, and IEEE 802.11p with paired seeds
10 through 29. It calculates each seed's normalized area under the raw
`correct / (correct + error + blocked)` PRR curve through 300 m. The
correctness contract requires the deterministic paired-bootstrap 95%
confidence interval for low-minus-high load to be strictly positive. The
medium-load mean is retained as a trend diagnostic rather than a strict
ordering assertion.

For focused development runs, set
`V2XSIM_DENSITY_REGRESSION_SEED_COUNT` to use the first N seeds beginning at
10, and/or set `V2XSIM_DENSITY_REGRESSION_DURATION_SECONDS`. These overrides
change test strength and must not be presented as the full regression.

Each technology/count/seed tuple has its own output directory and can be
scheduled on process workers through
`v2xsimregression.execution.runWorkItems`. Thread pools are intentionally not
used because the legacy simulator mutates process-wide state. A temporary pool
uses every worker exposed by the local `Processes` profile by default.
