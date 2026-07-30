# V7 correctness and integration testing

V7 tests are organized by the contract they protect, rather than by the
implementation object that happens to own the data today. This is important
while legacy state containers such as `positionManagement` and
`stationManagement` are being retired: a refactor may change those structures,
but it must not change vehicle identity, lifecycle events, geometry, radio
semantics, or reported results.

## Correctness gate

Run the complete ordinary test suite with coverage (decision coverage when
available) from the project root:

```matlab
addpath("tests")
[results, reportDirectory] = runCorrectnessSuite;
```

The runner discovers every test below `tests`, restores the caller's MATLAB
path, working directory, global random stream, and warning configuration,
writes the HTML coverage report to a unique temporary directory, and throws
if any test is unsuccessful. By default it runs the ordinary suite on all
workers exposed by the local `Processes` profile. It preserves a caller-owned
process pool; `ExecutionMode="serial"` is an explicit debugging override. To
keep a report at a chosen location:

```matlab
runCorrectnessSuite(CoverageDirectory="artifacts/coverage")
```

Statement, decision, condition, and MC/DC coverage can be selected with
`CoverageMetric`. The default `auto` mode prefers decision coverage because
branches at lifecycle, technology, and output boundaries are particularly
likely to hide scientific errors. Decision, condition, and MC/DC metrics
require MATLAB Test™; when that optional product is unavailable, `auto` emits
an explicit warning and falls back to statement coverage. Asking for a
non-statement metric explicitly still fails if it is unavailable. Coverage is
evidence of exercised code, not a substitute for behavioral assertions.

Regression tests are excluded from the ordinary-only default. Setting
`IncludeRegressionTests=true` adds routine behavioral regressions and
shortened conclusion-level publication campaigns. Registered full-duration
methods tagged `PublicationCampaign` remain excluded unless
`IncludePublicationCampaigns=true` is also supplied. A shortened result does
not prove a full-duration publication conclusion. When included, regression
test methods run serially on the client because their campaign runners own the
parallel work-item boundary and reuse the profile-sized process pool. This
avoids unsupported nested pools while preserving parallel campaign execution.

Run the complete automated ordinary-plus-routine-regression gate from a fresh
MATLAB session with:

```matlab
project = openProject("FWLabsV2XSim.prj");
cluster = parcluster("Processes");
fprintf("Processes profile exposes %d workers.\n", cluster.NumWorkers);
addpath("tests")
[results, reportDirectory] = runCorrectnessSuite( ...
    IncludeRegressionTests=true, ...
    ExecutionMode="parallel");
```

When no pool exists, the runner requests exactly `cluster.NumWorkers`. A
caller-owned process pool is preserved, so close an intentionally smaller pool
before starting the gate if the full configured capacity is required.

This command includes the shortened Bazzi and Zhuofei conclusion campaigns,
the fixed 10-second Vittorio conclusion campaigns, density and coexistence
regressions, and campaign-runner contracts. It excludes Bazzi's 4 km,
120-second publication profile.

Registered full-duration publication tests are an explicit opt-in:

```matlab
[results, reportDirectory] = runCorrectnessSuite( ...
    IncludeRegressionTests=true, ...
    IncludePublicationCampaigns=true, ...
    ExecutionMode="parallel");
```

`IncludePublicationCampaigns=true` requires
`IncludeRegressionTests=true`. Full-duration or exhaustive registered test
methods must carry the exact `PublicationCampaign` tag. The
`ShortCampaign` tag is descriptive; default exclusion is controlled by
`PublicationCampaign`.

Even the publication opt-in does not expand the intentionally separate,
exhaustive Zhuofei paper matrices containing thousands of 120-second
simulations. Those matrices are direct runner workflows documented in their
paper READMEs and are not registered test methods.

## Integration contracts

The integration suite protects these cross-component behaviors:

- vehicle names remain stable while vehicles enter and exit, with exact
  `Entered`, `Exited`, and `Unchanged` lifecycle sets;
- physical and apparent geometry, awareness ranges, and technology-specific
  neighbor lists agree at mixed-technology and empty/singleton boundaries;
- named resource assignments, reservations, and sensing state project into
  legacy dense rows without identity drift, and departed vehicles are removed;
- legacy neighbor and packet events carry the same names, endpoints, counts,
  distances, and outcomes observed by V7 hooks;
- IEEE 802.11p receive, interference, backoff-freeze, resume, and idle
  transitions preserve their exact state and timing semantics;
- complete simulations reconcile recorder CSV rows with summary counts and
  configuration for IEEE 802.11p, LTE-V2X, NR-V2X, and coexistence modes;
- enabling observer hooks does not alter deterministic simulation results;
- failed runs do not publish a completion summary or retain an output lock;
- supported scenario and radio-mode combinations complete with finite,
  internally consistent summaries;
- orthogonal LTE-V2X/IEEE 802.11p coexistence measurably outperforms the
  otherwise identical shared-channel mode using pooled raw packet fates.

These contracts intentionally avoid asserting the layout of
`positionManagement` or `stationManagement`. When those containers are split
or removed, adapters may change while the integration assertions remain.

## Long-running behavioral regressions

The controlled [density regression](../regression-tests/+v2xsimregression/+density/README.md)
holds geometry, motion, traffic, channel, and allocation settings fixed and
requires the paired 95% confidence interval for low-load minus high-load raw
PRR-AUC to be positive for LTE-V2X, NR-V2X, and IEEE 802.11p.

The focused [coexistence regression](../regression-tests/+v2xsimregression/+coexistence/README.md)
uses paired seeds and pooled raw packet fates to distinguish orthogonal
LTE-V2X/IEEE 802.11p operation from otherwise identical shared-channel
operation. Publication-level mitigation conclusions remain separate,
explicitly tagged regressions.

The [Bazzi et al. 2020 wireless-blind-spot regression](../regression-tests/+v2xsimregression/+paper/+bazzi2020blindspots/README.md)
combines a fast analytical two-vehicle oracle with a routine shortened
highway campaign. It pools raw PRR and wireless-blind-spot counts across
paired seeds and checks bounded real-simulator count, density, and congested
cap-ordering contracts. Its 4 km, 120-second publication profile is the
separate conclusion-level run; it is not implied by the shortened result.

## Parallel execution

Independent density points, seeds, and campaign configurations may be
distributed across local **process** workers. Thread workers are not supported
while the legacy simulator mutates process-wide state. When a runner creates a
pool, its size is `parcluster("Processes").NumWorkers`; the number of work
items and the profile's preferred interactive pool size do not silently shrink
that pool. A caller-owned process pool is an explicit caller choice and is
preserved. `MaxWorkers` remains available only as an explicit finite cap.

Each work item must have an exclusive output directory and component-owned
seed, and runners must restore the MATLAB path, current folder, warning state,
explicitly declared environment variables, and global random stream even when
a work item fails.

Long campaigns should pass `ProgressLogFile` to
`v2xsimregression.execution.runWorkItems`. The scheduler writes an append-only
JSON Lines journal from the client process, with queued, started, heartbeat,
completed, and failed events. Each record carries a client receive sequence,
UTC timestamp, work-item label/index, and a unique attempt identifier so a
worker-abort retry is distinguishable from an invalid state transition.
Workers with a fixed two-input signature receive a process-safe
`reportProgress` callback; existing one-input, optional-input, and variadic
workers retain their historical one-input invocation.

Campaigns should persist their manifest before dispatch and print the absolute
manifest and journal paths. Append-only journals provide best-effort crash
diagnostics rather than a durable transaction log. Readers should ignore a
torn final JSON line, and an abrupt operating-system failure may also lose
several recent records. Complete records that survive remain independently
parseable. Heartbeats provide diagnosis and partial progress evidence, but the
current `parfor` backend does not enforce a per-item timeout or cancellation
policy.
