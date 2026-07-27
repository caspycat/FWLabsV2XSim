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
- Methods B and F can improve NR-V2X use of its reserved slot, but usually
  reduce IEEE 802.11p range and increase its delay.
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
| 10 | At 6 vehicles/km with a balanced technology mix, A and C improve or preserve IEEE 802.11p PRR and extend its 90% range by at least 100 m, without materially reducing NR-V2X PRR. |
| 10 | B and F retain their IEEE 802.11p range tradeoff, distinguishing A/C from methods that merely move performance between technologies. |
| 11-12 | A, B, and F increase IEEE 802.11p end-to-end delay; both C variants leave its delay and data age comparable to no mitigation; NR-V2X delay remains comparable across methods. |
| 15 | Normalized PRR remains comparable between periodic and ETSI-CAM traffic, and the A/C conclusion is preserved. |

Normalized PRR is the area under the pooled PRR-versus-distance curve from
0 to 1500 m. It is less brittle than matching a single Monte Carlo point.
`RangeAt90Meters` is the first linearly interpolated downward crossing of
PRR = 0.9.

The default regression uses six 5-second seeds for Figures 10-12 and three
5-second seeds per traffic pattern for Figure 15. This is a calibrated sample
of the paper's much larger campaign, not a claim of numerical reproduction.
Set `V2XSIM_PAPER_SIMULATION_TIME_SECONDS` to use a longer duration. Very short
durations can make the statistical assertions unstable.

## Refactored parameter mapping

The legacy paper scripts remain unmodified and are outside this migration.
The package-local `config/cochannel.cfg` and `runPublishedCampaigns` use the
V7 API and have no runtime dependency on `old_src/codeForPaper`.

| Paper-era input | V7 input |
|---|---|
| `ETSI-Highway` | `BidirectionalHighwayScenario` |
| `rho` | `scenarioOptions.VehicleCount = density * 8 km` |
| `roadLength`, `roadWidth`, `NLanes` | `scenarioOptions.RoadLength`, `LaneWidth`, `NLanes` |
| `vMean = 120`, `vStDev = 12` km/h | `scenarioOptions.MeanVehicleSpeed = 120/3.6`, `VehicleSpeedStandardDeviation = 12/3.6` m/s |
| `averageTbeacon` | `application.ResourceReservationIntervalSeconds` |
| empty PER-curve directory | `channel.PacketErrorRateCurveDirectory = null` |

`BidirectionalHighwayScenario` is intentional. The refactored
`EtsiHighwayScenario` exposes the standardized 250/140/70 km/h traffic points,
whereas the paper sweeps arbitrary density at 120 +/- 12 km/h.

The legacy unbalanced scripts refer to nonexistent `wp_*.cfg` files, and the
balanced script selects 60 seconds despite its 120-second comment. The
regression does not execute or repair those scripts: its namespaced runner
defines the V7 method settings and calibrated duration explicitly.

The old placement balanced lane and direction counts exactly. The refactored
scenario samples lanes and directions, so the regression pairs each
`simulation.RandomSeed` with the same `scenarioOptions.RandomSeed` and pools
counts rather than expecting identical numerical curves.

## Run

From the repository root:

```matlab
addpath("src");
addpath("regression-tests");
suite = matlab.unittest.TestSuite.fromClass( ...
    ?v2xsimregression.paper.zhuofei2023cochannel. ...
    Zhuofei2023CoChannelTest);
results = run(suite);
assertSuccess(results);
```

The runner is configurable for a broader paper sweep:

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
        SimulationTimeSeconds=120);
```

That full matrix is intentionally not the default test: it contains thousands
of long simulations. Every run writes the simulator's raw outputs plus
`campaign-summary.csv`.
