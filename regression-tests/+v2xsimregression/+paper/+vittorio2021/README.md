# Published-paper regression tests

These long-running tests check that FWLabsV2XSim still supports the
conclusions of published WiLabV2XSim v6 studies. They are separate from
`tests/` so the ordinary unit and smoke suite stays fast.

## Todisco et al. 2021

`v2xsimregression.paper.vittorio2021.Vittorio2021PerformanceTest` reproduces
the V6.2 campaigns behind Figures 7, 9, and 11 of:

> V. Todisco et al., "Performance Analysis of Sidelink 5G-V2X Mode 2 Through
> an Open-Source Simulator," IEEE Access, 2021,
> DOI 10.1109/ACCESS.2021.3121151.

The contract is conclusion-level:

| Figure | Regression contract |
|---|---|
| 7 | Higher SCS improves PRR when IBE is modeled; removing IBE improves the 15 and 30 kHz cases; without IBE the SCS curves are comparable. |
| 9 | At -110 dBm, L2 with M=20% outperforms M=50% and legacy Mode 2; lowering the threshold to -126 dBm improves legacy Mode 2 and makes the L2 choices comparable. |
| 11 | Incoherent arrivals hurt legacy Mode 2; restoring both L2 selection and RSRP averaging is better than restoring either mechanism alone and approaches the coherent-arrival result. |

The score used for comparisons is normalized area under the PRR-versus-distance
curve. This is less brittle than matching individual Monte Carlo samples or
published plot pixels.

Run the published 10-second campaigns from the repository root:

```matlab
addpath("src");
addpath("regression-tests");
suite = matlab.unittest.TestSuite.fromClass( ...
    ?v2xsimregression.paper.vittorio2021.Vittorio2021PerformanceTest);
results = run(suite);
assertSuccess(results);
```

`runPublishedCampaigns` uses local process workers by default when Parallel
Computing Toolbox is available. It reuses a caller-owned process pool or opens
and closes a temporary one. Limit CPU use or select the backend explicitly:

```matlab
campaign = ...
    v2xsimregression.paper.vittorio2021.runPublishedCampaigns( ...
        string(pwd), string(tempname), ...
        Figures=[7, 9, 11], ...
        ExecutionMode="parallel", MaxWorkers=4);
```

`ExecutionMode="serial"` never opens a pool. `"auto"` falls back to serial
with a warning when parallel capability is unavailable, while an explicit
`"parallel"` request fails. Completion order never changes result-table order.
Thread pools are intentionally unsupported because the simulator changes
process-wide MATLAB state.

The suite targets the current repository layout. To exercise another checkout
of the current simulator, set its repository root before creating the suite:

```matlab
setenv("V2XSIM_PAPER_SIMULATOR_ROOT", ...
    "/path/to/current/FWLabsV2XSim");
```

The paper-era implementation at commit
`720080210ada63a7e752809f2f936e74783b4d31` from the untouched repository
was used as the publication oracle while building this regression. The
regression itself runs only the current simulator; the historical commit is
provenance, not a second supported layout.

The adapted campaigns express the paper's legacy scenario as an explicit
`BidirectionalHighwayScenario`: 200 vehicles on a 2 km, 3+3 lane highway,
4 m lane width, and speeds of 70 +/- 7 km/h. Radio, MAC, seed, and
figure-specific settings remain those in the adapted
`old_src/codeForPaper/Vittorio2021Performance` scripts.

The modern resource-selection API retains the paper's two independent
controls. `ratioSelectedAutonomousMode=0.2` sets the 20% minimum that must
survive RSRP filtering. `ratioSelectedL2` sets the final L2 shortlist to 20%,
50%, or 100%, and `L2active` enables or bypasses that ranking step.
`averageSensingActive` replaces the paper-only `avgRSRPin5G` name. Therefore
all Figure 9 cases, including the 20% floor with a 50% L2 shortlist, are now
represented exactly.

When `ratioSelectedL2` is omitted, it defaults to
`ratioSelectedAutonomousMode`. Existing callers therefore retain the former
single-ratio behavior unless they explicitly adjust the second knob.

The result table exposes these choices separately as
`ThresholdFloorFraction`, `L2SelectionFraction`, and
`resourceAllocation.Autonomous.L2RankingEnabled`.

The files under `old_src/codeForPaper/Vittorio2021Performance` are retained as
historical provenance. Their plotting readers use the old numbered output
filenames and are not supported V7 interfaces. The package-local
`runPublishedCampaigns` implementation owns the migrated scenario,
resource-selection inputs, per-run directories, and suffixless CSV readers.

When the journal and archived executable configuration disagree, the
regression uses the value that reproduces the published curve or supports its
stated conclusion. The disagreement and selected value must remain documented.
The calibrated campaigns retain the executable configuration's 6 dB receiver
noise figure; the journal reports 9 dB, but that value prevents the original
Figure 7 setup from covering its published 150 m axis. Figure 11 retains the
executable campaign's fixed 200 ms generation interval: an RRI of 100 ms
represents the incoherent cases and an RRI of 200 ms the coherent benchmark.
The journal instead describes motion-driven ETSI CAM intervals averaging
approximately 207 ms. The retained executable settings pass the full-duration
conclusion-level regressions.
