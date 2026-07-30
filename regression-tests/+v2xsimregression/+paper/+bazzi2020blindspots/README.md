# Bazzi et al. 2020 wireless-blind-spot regression

This suite reasserts the scientific claims of:

> A. Bazzi et al., "On Wireless Blind Spots in the C-V2X Sidelink,"
> *IEEE Transactions on Vehicular Technology*, vol. 69, no. 8,
> pp. 9239-9243, 2020. DOI
> [10.1109/TVT.2020.3001074](https://doi.org/10.1109/TVT.2020.3001074).

## Scientific contract

Semi-persistent scheduling improves packet-reception reliability when a
vehicle retains a favorable resource, but a persistent collision can create a
long wireless blind spot. The paper's proposed cap on consecutive reservation
intervals bounds that persistence and exposes a controllable tradeoff:
increasing the cap from two to five intervals recovers PRR while increasing
the wireless-blind-spot tail.

The regression is conclusion-level. It does not match figure pixels or claim
to recreate unpublished random seeds. Uniform fixed-count placement on the
periodic highway is the v7 conditional one-dimensional Poisson realization.
Simulation, scenario, and allocator streams are independent, but receive the
same numeric seed so allocation schemes remain paired.

The paper does not publish its random seeds, simulation runtime, campaign
scripts, or WBS awareness radius. The seeds, durations, 100 m WBS range, and
campaign orchestration below are therefore explicit v7 adaptation choices,
not recovered archival settings.

The common setup is LTE-V2X with 300-byte beacons at 10 Hz, MCS 6, 10 MHz,
23 dBm transmit power, 3 dB transmit/receive antenna gains, 9 dB receiver
noise figure, a 5.79 dB decode threshold, correlated WINNER+ B1 shadowing,
reselection counters 5-15, and awareness ranges 100 and 300 m. WBS contracts
use the 100 m range. The channel-load scheduler remains enabled with a 0.1 s
window and 100 update steps because autonomous allocation consumes its timing
state. Congestion control and channel-busy-ratio output remain disabled, so
this does not add a reported CBR metric or load-adaptive traffic behavior.

| Profile | Highway conditions (vehicles/km, km/h) | Schemes | Seeds | Duration |
|---|---|---|---|---|
| `shortened` | (100, 140), (400, 50) on 1 km | legacy \(p_k=0\), legacy \(p_k=0.8\), capped \(m=2,5\) | `10:14` | 30 s |
| `publication` | (100, 140), (200, 100), (400, 50) on 4 km | legacy controls and capped \(m=2:5\) | `10:19` | 120 s |

The shortened profile requires paired 95% percentile-bootstrap intervals to
show the legacy PRR/WBS tradeoff and lower WBS-tail exposure under each cap.
The five-interval cap must remain within 0.03 normalized PRR AUC of legacy
retention. This is a routine scientific regression proxy, not proof that the
full paper surfaces still hold.

The publication profile additionally requires every capped scheme to retain
at least 75% of the legacy-\(0.8\) PRR=0.9 range and shorten the \(10^{-4}\)
WBS duration. Increasing the cap from two to five must preserve/improve PRR
while increasing WBS-tail exposure. In the congested case, legacy retention
must cross \(10^{-4}\) after 10 s (or remain right-censored beyond it), while
the five-interval cap must cross before 8 s.

## Metrics and evidence

Raw counts are pooled across seeds before aggregate curves are derived:

- `PrrAuc0To300` is normalized trapezoidal PRR area over 0-300 m. The
  distance-zero anchor uses the first 10 m bin's PRR.
- `PrrRangeAt90Meters` is the first linearly interpolated downward PRR=0.9
  crossing, bounded at 300 m when no crossing is observed.
- `WbsTailProbabilityAuc2To10Seconds` is the unnormalized integral of WBS
  tail probability from 2-10 s at 100 m.
- `WbsThresholdCrossingSeconds` is the first linearly interpolated
  \(10^{-4}\) crossing over the full generated 15 or 20 s WBS curve.
  `WbsThresholdCrossingStatus` is `crossed`, `left_censored`, or
  `right_censored`; censored values are observation-window bounds, not
  ordinary crossings.

The per-seed metrics are retained for paired bootstrap comparisons. Bootstrap
resampling uses a component-owned deterministic stream and never consumes the
MATLAB global random stream.

## Analytical oracle

The `+analysis` package implements the paper's two-vehicle model directly:
`tbePmf` covers Equation 1, `intervalCountPmf` Equation 2, and `tbcPmf`
Equations 3-8 using discrete convolution. `expectedTbcDuration` evaluates the
closed-form mean, `resourceUnchangedProbability` implements Equations 10-11
with the constant \(1+S(1)\) denominator, and
`wirelessBlindSpotProbability` completes Equation 12.
`monteCarloTbcPmf` provides an independent seeded validation with a
component-owned random stream.

Run the analytical scientific regression:

```matlab
addpath("regression-tests");
results = run(matlab.unittest.TestSuite.fromClass( ...
    ?v2xsimregression.paper.bazzi2020blindspots. ...
    Bazzi2020AnalyticalTest));
assertSuccess(results);
```

Every run writes:

- `campaign-seed-summary.csv`, one diagnostic row per work item;
- `campaign-summary.csv`, one pooled row per scenario and scheme;
- `campaign-comparisons.csv`, candidate-minus-reference paired means and
  95% percentile intervals;
- raw simulator artifacts below each scenario/scheme/seed directory.

## Run

Run the fast reducer/orchestration tests:

```matlab
addpath("src");
addpath("regression-tests");
results = run(matlab.unittest.TestSuite.fromClass( ...
    ?v2xsimregression.paper.bazzi2020blindspots. ...
    Bazzi2020ReducerTest));
assertSuccess(results);
```

Run the routine shortened campaign:

```matlab
openProject("FWLabsV2XSim.prj");
addpath("regression-tests");
suite = matlab.unittest.TestSuite.fromClass( ...
    ?v2xsimregression.paper.bazzi2020blindspots. ...
    Bazzi2020BlindSpotTest);
suite = suite.selectIf( ...
    matlab.unittest.selectors.HasTag("ShortCampaign"));
results = run(suite);
assertSuccess(results);
```

Run the publication-scale profile only when the full scientific evidence is
needed:

```matlab
openProject("FWLabsV2XSim.prj");
addpath("regression-tests");
suite = matlab.unittest.TestSuite.fromClass( ...
    ?v2xsimregression.paper.bazzi2020blindspots. ...
    Bazzi2020BlindSpotTest);
suite = suite.selectIf( ...
    matlab.unittest.selectors.HasTag("PublicationCampaign"));
results = run(suite);
assertSuccess(results);
```

To retain publication-profile raw artifacts and summary tables outside the
test fixture, invoke the runner directly:

```matlab
openProject("FWLabsV2XSim.prj");
addpath("regression-tests");
[aggregate, comparisons] = ...
    v2xsimregression.paper.bazzi2020blindspots. ...
    runPublishedCampaigns( ...
        string(pwd), ...
        fullfile(string(pwd), "output", "bazzi2020-publication"), ...
        Profile="publication", ...
        ExecutionMode="parallel");
```

The publication profile contains 180 long simulations with up to 1600
vehicles. Its scheduler defaults to four local process workers; an explicit
finite `MaxWorkers` value overrides that conservative default. Parallel
Computing Toolbox remains optional; `ExecutionMode="auto"` falls back to
serial execution when it is unavailable. The fast Bazzi reducer suite drives
the real campaign runner through a count-preserving mock simulator to verify
serial/parallel result ordering, isolated output paths, CSV persistence, and
caller-state restoration after success and failure. The shared
`v2xsimregression.execution.runWorkItems` suite additionally verifies
caller-owned pool retention and aggregated failure reporting.
