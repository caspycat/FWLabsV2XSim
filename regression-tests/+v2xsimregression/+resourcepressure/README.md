# Resource-pressure regression

This conclusion-level regression measures the capacity effect of the static
`Radio.Sidelink.ResourcePool.ResourcePressure` experiment control. It holds
the NR-V2X PHY configuration, road geometry, mobility, offered traffic,
packet sizing, and each allocator's configuration fixed. The treatment alone
changes from `100%` time and frequency availability to `25%` on each axis
(6.25% of the original Cartesian-product BR capacity).

The campaign covers every supported allocator: `ReuseDistance`,
`MaximumReuseDistance`, `MinimumReusePower`, `SensingBased`, `Random`, and
`Ordered`. For each allocator it pairs both treatments by seed and calculates
the normalized raw PRR-AUC over 0--300 m. The contract is that the paired
bootstrap 95% confidence interval for unpressured minus pressured PRR-AUC is
strictly positive. This checks an inverse capacity--PRR relationship without
claiming that every individual Monte Carlo seed must be monotonic.

The default uses seeds 10--19 and two simulated seconds per work item. During
focused development, `V2XSIM_RESOURCE_PRESSURE_REGRESSION_SEED_COUNT` and
`V2XSIM_RESOURCE_PRESSURE_REGRESSION_DURATION_SECONDS` can shorten the run.
Those overrides reduce statistical strength and are not evidence for the full
conclusion-level contract.
