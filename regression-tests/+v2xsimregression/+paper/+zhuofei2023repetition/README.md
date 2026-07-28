# Zhuofei et al. 2023 adaptive-repetition regression

This suite reasserts the conclusions of:

> W. Zhuofei, S. Bartoletti, V. Martinez, and A. Bazzi,
> "Adaptive Repetition Strategies in IEEE 802.11bd V2X Networks,"
> IEEE Transactions on Vehicular Technology, 2023,
> DOI 10.1109/TVT.2023.3241865.

## TL;DR

IEEE 802.11bd can send up to three repetitions after the first broadcast
transmission. Repetition adds time diversity, and a receiver can combine
copies through maximum-ratio combining (MRC). The gain is conditional: a copy
can be stored and combined only when its preamble is detected. Repetition also
occupies the channel for longer, increasing collision probability.

The paper makes two main contributions:

1. It evaluates repetition at network level, including both preamble
   acquisition and packet decoding. This exposes the load-dependent tradeoff
   that link-only analyses miss.
2. It proposes deterministic and probabilistic distributed strategies that
   adapt the repetition count from a locally measured *net CBR*. Net CBR
   counts only the first detected copy of each packet, so the control input
   does not directly feed back on the number of repetitions it selects.

The result is not "more repetitions are always better":

- Figure 3 shows that ideal preamble detection overstates MRC gains. At the
  realistic -100 dBm threshold, repetitions still help, but the gain is
  limited at long range. A receiver capable of -103 dBm detection recovers
  more of the ideal gain.
- Figure 4 shows that more repetitions improve the 90%-PRR range at low net
  CBR and reduce it at high net CBR. The crossover thresholds used by the
  strategies are 0.03, 0.05, and 0.09. Above approximately 0.09, zero
  repetitions outperform one repetition. WINNER+ B1 and ECC rural propagation
  change the distance scale but preserve the load-dependent ordering.
- Figure 5 shows that both adaptive strategies stay close to the best fixed
  repetition count as vehicle density changes. They therefore exploit
  diversity when the channel is free and back off when it is congested.
- Figure 6 shows a fairness difference rather than a further PRR gain.
  Deterministic decisions can leave nearby vehicles locked into different
  counts for long intervals. Probabilistic decisions vary more over time and
  give neighboring vehicles more similar long-run access.

## Regression contract

The contract is conclusion-level. It does not compare plot pixels or require
the published Monte Carlo samples.

| Paper figure | Regression assertion |
|---|---|
| 3 | With no repetition, preamble thresholds have negligible effect. With three repetitions, -100 dBm improves PRR over no repetition, -103 dBm improves over -100 dBm, and ideal detection retains a further advantage. |
| 4 | At net CBR below 0.03, three repetitions improve PRR. Above 0.09, they reduce PRR. The sign of this tradeoff is the same with WINNER+ B1 and ECC rural propagation. |
| 4 | On the sampled WINNER+ load sweep, one repetition remains beneficial near the crossover, while zero repetitions beat one repetition at high load. |
| 5 | At 5, 40, and 80 vehicles/km, deterministic and probabilistic adaptation remain within a tolerance of the best fixed count and remain comparable with each other. |

Raw successful- and total-packet counts are pooled across deterministic seeds
before PRR is calculated. The pooled data are combined into 50 m bins.
`NormalizedPrrScore` is the area under the PRR-versus-distance curve, normalized
over 0-650 m for WINNER+ B1 and 0-2000 m for ECC rural.
`RangeAt90Meters` is the first interpolated downward crossing of PRR = 0.9.
`MeanNetCbr` is reconstructed from the simulator's empirical CBR distribution
and averaged across seeds.

Figure 6 is deliberately not asserted by the standard-output regression. The
legacy plot depends on commented, paper-specific hooks that save per-vehicle
repetition and position matrices; there is no public V7 output for those data.
Re-enabling hidden hooks in a regression would couple the test to simulator
internals. A future public repetition-decision log could support a focused
contract: comparable global mean repetitions and PRR, a higher decision-switch
rate for the probabilistic strategy, and lower between-vehicle variance in
long-run repetition count.

## Calibrated sample

The default test is a compact sample of the paper's much larger campaign:

- Figure 3: -100, -103, and -120 dBm with one and four total transmissions,
  pooled over three seeds.
- Figures 4-5: WINNER+ B1 at 5, 40, and 80 vehicles/km with one through four
  total transmissions plus both adaptive strategies, pooled over two seeds.
- Figure 4 propagation check: ECC rural at the low/high density bookends with
  one and four total transmissions, pooled over two seeds.
- Five seconds per seed by default.

`MaximumTransmissionCount` includes the original transmission: 1 means zero
repetitions and 4 means three repetitions. Set
`V2XSIM_PAPER_SIMULATION_TIME_SECONDS` to run a longer duration. Durations much
shorter than the default can make the stochastic assertions unstable.

Every run retains the raw simulator files. The campaign root also contains
`campaign-summary.csv`.

## Refactored parameter mapping

The legacy scripts under `old_src/codeForPaper/Zhuofei2023Repetition` are
outside this migration and remain unmodified. The regression has no runtime
dependency on that directory, so it can be removed with the rest of
`old_src/codeForPaper`. The V7 configurations are owned by this regression
package under `config/`, and `runPublishedCampaigns` applies each campaign
sweep directly.

| Paper-era input | V7 input |
|---|---|
| `ETSI-Highway` | `BidirectionalHighwayScenario` |
| `rho` | `scenarioOptions.VehicleCount = round(rho * roadLength / 1000)` |
| `roadLength`, `roadWidth`, `NLanes` | `scenarioOptions.RoadLength`, `LaneWidth`, `NLanes` |
| `vMean = 120`, `vStDev = 12` km/h | `scenarioOptions.MeanVehicleSpeed = 120/3.6`, `VehicleSpeedStandardDeviation = 12/3.6` m/s |
| `averageTbeacon` | `application.ResourceReservationIntervalSeconds` and `application.PacketGeneration.IntervalSeconds` |
| implicit CBR schedule | `channelLoad.Enabled`, `MeasurementWindowSeconds`, and `UpdateStepsPerWindow` |
| seed `0` | matching deterministic positive `simulation.RandomSeed` and `scenarioOptions.RandomSeed` values |

`BidirectionalHighwayScenario` is intentional. `EtsiHighwayScenario` exposes
the standardized ETSI traffic points, while this paper varies density at
120 +/- 12 km/h.

The paper scripts use a 2 km WINNER+ road at density `D`. For ECC rural they
use an 8 km road at density `D/4`; both cases therefore contain `2D` vehicles.
The current scenario samples lanes and travel directions rather than enforcing
the legacy script's exact balance, so the regression pairs the simulation and
scenario seeds and pools those replicates.

Keeping the migrated runner and fixtures here prevents a V7-only test harness
from making the historical paper scripts appear compatible with the current
simulator.

## Run

From the repository root:

```matlab
addpath("src");
addpath("regression-tests");
suite = matlab.unittest.TestSuite.fromClass( ...
    ?v2xsimregression.paper.zhuofei2023repetition. ...
    Zhuofei2023RepetitionTest);
results = run(suite);
assertSuccess(results);
```

The public runner can also produce a broader sweep:

```matlab
root = string(pwd);
results = ...
    v2xsimregression.paper.zhuofei2023repetition. ...
    runPublishedCampaigns( ...
        root, fullfile(root, "output", "zhuofei2023-repetition"), ...
        Figures=[3, 4, 5], ...
        RandomSeeds=1:20, ...
        SimulationTimeSeconds=120, ...
        ExecutionMode="parallel", ...
        MaxWorkers=8, ...
        LoadDensitiesVehiclesPerKilometer=[1:10, 12:2:30, 40:20:100], ...
        StaticTransmissionCounts=1:4, ...
        EccDensitiesVehiclesPerKilometer=[1:10, 12:2:30, 40:20:100], ...
        EccTransmissionCounts=1:4);
```

That full matrix is intentionally not the default regression: it contains
thousands of long simulations.

Each configuration/seed pair is an independent work item. With Parallel
Computing Toolbox, `ExecutionMode="auto"` (the default) reuses a local process
pool or creates and later closes a temporary one. Use `"serial"` to prohibit
pool creation or `"parallel"` to require the toolbox and a usable process
pool. `MaxWorkers` caps CPU use. Aggregation and CSV writing remain on the
client in deterministic campaign order.

MATLAB `mapreduce` and Spark are not execution backends for these campaigns:
they target distributed data analytics rather than independent MATLAB
simulation jobs. A future cluster backend can reuse the work-item boundary,
but MATLAB Parallel Server is not currently required or supported.
