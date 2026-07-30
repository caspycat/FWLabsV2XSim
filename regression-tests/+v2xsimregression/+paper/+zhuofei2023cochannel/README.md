# Wu et al. 2023 co-channel coexistence regression

This suite reasserts the conclusions of:

> Z. Wu, S. Bartoletti, V. Martinez, V. Todisco, and A. Bazzi,
> "Analysis of Co-Channel Coexistence Mitigation Methods Applied to
> IEEE 802.11p and 5G NR-V2X Sidelink," Sensors, 2023,
> DOI 10.3390/s23094337.

## TL;DR

The paper is the first evaluation of the ETSI A-F coexistence proposals after
adapting them from ITS-G5/LTE-V2X to IEEE 802.11p/5G NR-V2X. It accounts for
two important NR differences: configurable numerology and a sensing procedure
driven mainly by decoded control reservations rather than average received
power. It compares Methods A, B, C, a simplified C without a superframe, and F
on a six-lane highway using transmission range, end-to-end delay, and data age.

The main result is a tradeoff, not a universal winner:

- At low density, enhanced Method A and both Method C variants are the only
  broadly Pareto-positive choices. They improve one technology's range without
  materially hurting the other.
- Method A usually gives the largest range, but its time split delays
  IEEE 802.11p packets by roughly 5-10 ms.
- Method C lets IEEE 802.11p sense NR-V2X transmissions through an inserted
  802.11p preamble. It improves IEEE 802.11p range while leaving delay and data
  age close to the no-method case. The simpler no-superframe variant performs
  at least as well in several scenarios.
- Method B exposes an IEEE 802.11p range and delay tradeoff at low density.
  Method F's IEEE 802.11p range loss is density-dependent and is checked
  separately at high density.
- Benefits shrink or change with density and technology mix. Periodic versus
  movement-triggered CAM generation has little effect for NR-V2X because its
  sensing relies on decoded sidelink reservations.
- The qualitative conclusions also apply to IEEE 802.11bd when it uses a
  comparable coding rate and packet duration; repetitions and channel bonding
  were explicitly left for future work.

## Regression contract

The contract is conclusion-level. Raw reception and histogram counts are
pooled across deterministic seeds before metrics are calculated.

| Paper figures | Regression assertion |
|---|---|
| 10 | At 6 vehicles/km with a balanced technology mix, A improves IEEE 802.11p normalized PRR by more than 0.005 and has a higher 90% range. Both C variants improve normalized PRR by at least 0.005 and may not lose more than one native 50 m distance bin of 90% range. A and C may reduce NR-V2X normalized PRR by no more than 0.01. |
| 10 | B reduces IEEE 802.11p 90% range, retaining the low-density tradeoff without treating normalized PRR as a range surrogate. |
| 10 | A focused 36 vehicles/km comparison requires F to reduce IEEE 802.11p 90% range. F is not required to lose normalized PRR at low density. |
| 11-12 | A, B, and F increase IEEE 802.11p end-to-end delay. Both C variants keep its delay within 2 ms of baseline and may increase its data age by no more than 2 ms. Each method's NR-V2X delay must remain within 10 ms of its no-method baseline; C's NR-V2X data-age increase is bounded by 10 ms. |
| 15 proxy | For periodic and ETSI-CAM traffic separately, A must improve IEEE 802.11p normalized PRR and both C variants must preserve it within 0.01 of the matching no-method baseline. |

Normalized PRR is the area under the pooled PRR-versus-distance curve from
0 to 1500 m. It is less brittle than matching a single Monte Carlo point.
`RangeAt90Meters` is the first linearly interpolated downward crossing of
PRR = 0.9.

The Figures 10-12 `ShortCampaign` regression uses seeds `10:15` and a
10-second duration. Five seconds did not retain the dynamic-C direction on the
disjoint `110:115` calibration block; doubling the duration did, without
changing the seeds or thresholds. The traffic-pattern proxy uses all six seeds
for each traffic pattern at an explicit 5-second duration. The
focused `HighDensity` F check uses seeds `10:12` at 36 vehicles/km, also for
5 seconds. The paper's Figure 15 plots transmission range across density,
whereas the short regression compares each traffic pattern with its own
baseline at one density. It therefore checks robustness of the qualitative
A/C conclusion; it does not
claim to reproduce Figure 15 numerically or prove that the two traffic
patterns' curves are equal. In particular, the short proxy makes no
baseline-relative NR-V2X assertion under ETSI-CAM traffic; the paper's
NR-V2X conclusion concerns the complete transmission-range curves across
density, which require the full-duration sweep.

Set `V2XSIM_PAPER_SIMULATION_TIME_SECONDS` to change the runner's default
duration when a caller does not pass `SimulationTimeSeconds`; the Figures
10-12 test passes its calibrated 10-second duration explicitly. Very short
durations can make the statistical assertions unstable. The fixed six-seed
blocks `10:15`, `110:115`, and `210:215` are reserved for recalibration. A
directional conclusion must retain its sign across those blocks before a
contract is changed. An ambiguous result is addressed by increasing the pooled
seed count or duration, never by selecting a favorable block or advancing a
stream until a campaign passes.

The 10-second duration was checked against the disjoint calibration blocks.
For `110:115`, the dynamic-C and no-superframe-C normalized-PRR gains were
0.01164 and 0.01350, with 90%-range changes of +93.97 m and +46.92 m. A full
six-method holdout on `210:215` passed every contract; the A, dynamic-C, and
no-superframe-C normalized-PRR gains were 0.03300, 0.01045, and 0.01022, and
their range changes were +186.02 m, +124.09 m, and +88.29 m. Method B's range
change was -682.47 m. These are calibration results, not publication-level
confidence intervals. For the density-36 Method F check, the disjoint
three-seed blocks `110:112` and `210:212` produced IEEE 802.11p range changes
of -121.67 m and -265.75 m.

## Randomness and diagnostics

The scenario owns its private random stream for placement and mobility.
`Simulation.RandomSeed` continues to control the simulator's radio/MAC
randomness, while `Scenario.BidirectionalHighway.RandomSeed` controls that
scenario stream.
The campaign deliberately pairs the same numeric value for both options. This
is a reproducible pairing convention across separately owned streams, not a
shared stream or an attempt to recreate the legacy draw order. The runner does
not burn or skip random draws to recover a historical sample.

The runner restores the saved MATLAB path, reinstalls the exact global
`RandStream` object that was active at entry, and restores its state, including
when a campaign fails or simulator code replaces the global stream.

Every campaign writes:

- `campaign-summary.csv`, whose rows contain metrics calculated after pooling
  raw counts across the requested seeds;
- `campaign-seed-summary.csv`, whose rows expose the same metrics per seed and
  record both `SimulationSeed` and `ScenarioSeed`;
- the simulator's raw output under the corresponding method and seed
  directory.

The per-seed file is diagnostic evidence. The regression assertions continue
to use the pooled summary rather than selecting favorable individual samples.

## Refactored parameter mapping

The legacy paper scripts remain unmodified and are outside this migration.
The package-local `config/cochannel.toml` and `runPublishedCampaigns` use the
V7 API and have no runtime dependency on `old_src/codeForPaper`.

| Paper-era input | V7 input |
|---|---|
| `ETSI-Highway` | `Scenario.Type = "BidirectionalHighway"` |
| `rho` | `Scenario.BidirectionalHighway.VehicleCount = density * 8 km` |
| `roadLength`, `roadWidth`, `NLanes` | `Scenario.BidirectionalHighway.RoadLength`, `LaneWidth`, `NLanes` |
| `vMean = 120`, `vStDev = 12` km/h | `Scenario.BidirectionalHighway.MeanVehicleSpeed = 120/3.6`, `VehicleSpeedStandardDeviation = 12/3.6` m/s |
| `averageTbeacon` | `Application.ResourceReservationIntervalSeconds` |
| empty PER-curve directory | resolved `Channel.PacketError.Model = "Threshold"`; `CurveDirectory` omitted |

`BidirectionalHighway` is intentional. The refactored
`EtsiHighway` scenario exposes the standardized 250/140/70 km/h traffic points,
whereas the paper sweeps arbitrary density at 120 +/- 12 km/h.

The legacy unbalanced scripts refer to nonexistent `wp_*.cfg` files, and the
balanced script selects 60 seconds despite its 120-second comment. The
regression does not execute or repair those scripts: its namespaced runner
defines the V7 method settings and calibrated duration explicitly.

The old placement balanced lane and direction counts exactly. The refactored
scenario samples lanes and directions with its component-owned stream, so the
regression pools counts rather than expecting identical numerical curves or a
legacy RNG trajectory.

## Run

From the repository root, run the default short campaigns:

```matlab
addpath("src");
addpath("regression-tests");
suite = matlab.unittest.TestSuite.fromClass( ...
    ?v2xsimregression.paper.zhuofei2023cochannel. ...
    Zhuofei2023CoChannelTest);
suite = suite.selectIf( ...
    matlab.unittest.selectors.HasTag("ShortCampaign"));
results = run(suite);
assertSuccess(results);
```

Run the focused high-density Method F check separately:

```matlab
suite = matlab.unittest.TestSuite.fromClass( ...
    ?v2xsimregression.paper.zhuofei2023cochannel. ...
    Zhuofei2023CoChannelTest);
suite = suite.selectIf( ...
    matlab.unittest.selectors.HasTag("HighDensity"));
results = run(suite);
assertSuccess(results);
```

The lightweight runner-contract tests use 0.2-second single-seed campaigns to
verify the diagnostics schema, restoration of the MATLAB path and exact global
random-stream object and state, and metric independence from method order:

```matlab
suite = matlab.unittest.TestSuite.fromClass( ...
    ?v2xsimregression.paper.zhuofei2023cochannel. ...
    RunPublishedCampaignsTest);
results = run(suite);
assertSuccess(results);
```

The runner is configurable for the full-duration paper sweep:

```matlab
root = string(pwd);
results = ...
    v2xsimregression.paper.zhuofei2023cochannel. ...
    runPublishedCampaigns( ...
        root, fullfile(root, "output", "zhuofei2023"), ...
        Methods=[ ...
            "only_NR", "only_ITS", "no_method", "enhanced_A", ...
            "method_B", "dynamic_C", "dynamic_C_preamble", "method_F"], ...
        DensitiesVehiclesPerKilometer=3:3:36, ...
        SidelinkFractions=[1/3, 1/2, 2/3], ...
        PacketIntervalVariationsSeconds=[0, -1], ...
        RandomSeeds=1:20, ...
        SimulationTimeSeconds=120, ...
        ExecutionMode="parallel");
```

Each method/density/traffic/seed tuple is an independent work item.
`ExecutionMode="auto"` (the default) uses a local process pool when Parallel
Computing Toolbox is available and otherwise warns and runs serially.
`ExecutionMode="serial"` never opens a pool; `"parallel"` requires one.
Caller-owned process pools are retained, temporary pools are closed, and
temporary pools use every worker exposed by the `Processes` profile. A finite
`MaxWorkers` value is an explicit CPU cap. Metrics and both summary files are
assembled on the client in their existing deterministic order.

Thread pools, MATLAB `mapreduce`, Spark, and remote MATLAB Parallel Server
clusters are outside this local multi-core backend. The common work-item
scheduler isolates pool acquisition so a cluster backend can be added later
without changing campaign definitions.

That full matrix is intentionally not the default test: it contains thousands
of long simulations. It is the appropriate workflow for checking the paper's
complete density and traffic-pattern surfaces; the short suite is only a
conclusion-level regression proxy.
