# Coexistence semantic regression

This package checks that LTE-V2X/IEEE 802.11p orthogonal coexistence and
shared-channel coexistence remain observably different after architecture
changes. It is an outcome-level regression, not just a configuration-parser
or output-schema check.

The paired manifest runs `COEX-NO-INTERF` and `COEX-STD-INTERF` with seeds
10 through 12. Both modes use the same 48 vehicles on the same 1 km,
six-lane highway, the same 24/24 technology pattern, component-owned seeds,
periodic traffic, channel model, and MAC/resource configuration. Only the
interference mode changes. Raw correct, error, and blocked packet counts are
pooled across seeds and across the ten 50 m bins through 500 m before PRR is
calculated.

The archived `.cfg` campaign inherited enabled channel-load measurement even
though it did not publish CBR files. The V7 TOML makes that measurement,
its 0.1 s window, and its 100 desynchronization steps explicit while keeping
congestion control and CBR output disabled. This preserves the established
simulation behavior and seeded random-stream consumption; channel-load
measurement and CBR artifact publication remain separate controls.

The correctness contract requires the orthogonal-mode pooled PRR to exceed
the shared-channel pooled PRR by more than 0.015 for both IEEE 802.11p and
LTE-V2X. During calibration, seeds 10 and 11 individually produced
orthogonal-minus-shared gains of 0.0357 to 0.0654 for IEEE 802.11p and
0.0263 to 0.0346 for LTE-V2X. The threshold therefore preserves a
substantial margin while detecting a missing or materially weakened
cross-technology interference path.

Each mode/seed tuple has an exclusive output directory and is an independent
work item scheduled by `v2xsimregression.execution.runWorkItems`.
`ExecutionMode="auto"` can use local process workers; thread workers are not
used because the simulator mutates process-wide MATLAB state. The scheduler
restores each execution process's current folder, MATLAB path, warning state,
and exact global random-stream object and state. A temporary pool uses every
worker exposed by the local `Processes` profile by default.

This focused comparison deliberately keeps the cellular technology fixed at
LTE-V2X so the interference-mode effect is not confounded with LTE-versus-NR
PHY/MAC differences. `COEX-STD-INTERF-5G` mitigation behavior remains covered
by the `ShortCampaign` tests in
`v2xsimregression.paper.zhuofei2023cochannel.Zhuofei2023CoChannelTest`.
Those conclusion-level regressions compare the no-method baseline with
Methods A, B, C, the preamble-only C variant, and F using pooled deterministic
seeds.

Run the focused regression from the repository root:

```matlab
addpath("src");
addpath("regression-tests");
suite = matlab.unittest.TestSuite.fromClass( ...
    ?v2xsimregression.coexistence.CoexistenceModeBehaviorTest);
results = run(suite);
assertSuccess(results);
```

For direct campaign use, `runModeComparison` accepts `ExecutionMode` and
`MaxWorkers`. It writes `seed-summary.csv`, `mode-comparison.csv`, and the
simulator outputs beneath a caller-provided path that must not already exist.
A finite `MaxWorkers` value is an explicit resource cap.
