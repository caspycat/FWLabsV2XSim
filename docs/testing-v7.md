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

Packet buffering has three complementary deterministic checks:

- `v2xsimtest.packet.PacketBufferTest` compares admission, eviction, retries,
  and drain operations against an independent list oracle at capacities 1, 2,
  3, and 64, checking conservation after every operation.
- `v2xsimtest.runtime.PacketBufferBridgeTest` verifies active reception/SINR
  preservation, packet identity on queued drops, and sidelink block handling.
  Recorder tests assert exact generation-to-reception delays, peak age, and
  histogram growth without lost counts.
- `OutputCountOracleTest` reconciles summary, PRR, and packet-fate output for
  capacity 1 and 3 across IEEE 802.11p, LTE, NR, and coexistence, and exercises
  overflow with saturated traffic both with and without repetitions. The repeated
  sidelink cases use the Random allocator, which supports multiple transmissions.
  Larger buffers are not required to reproduce
  the default one-slot blocked-packet count.

Repetition and coexistence shortened publication regressions remain the
scientific guardrails for the default capacity. They do not validate full-duration
publication conclusions or establish the scientific benefit of a larger buffer.

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

Controller-information coverage includes decimal fixed-delay boundaries,
source timestamps and report identities (`PositionDelayErrorTest`), eligible
resource/time ranks and regret (`MaximumReuseTraceTest`), reordered identity
tables and nearest co-user geometry (`ControllerDiagnosticsRecorderTest`),
and complete-priority fingerprint stability and allocator non-interference
(`ConcreteAllocatorTest`). `ControllerStateRunTest` runs a short delayed-MRD
simulation across highway coordinate wraps, joins consumed X values to the
position trace, and compares packet-fate and position traces with recording
disabled. Computation time is excluded from equality checks. These are bounded
correctness checks, not evidence for a full-duration imperfect-information
campaign or for a research module's custom re-entry policy.

## Resource-usage observer contracts

The resource-usage tests implement sections 5–7 of the 12 September 2026
`UPSTREAM_REQUIREMENTS.md` handoff for the imperfect-state-information study.
They use upstream-owned fixtures and do not read the campaign workspace.
The four required CSV contracts are tested with these suites:

| Suite | Contract evidence |
| --- | --- |
| `v2xsimtest.resource.ResourceUsageTest` | Hand-calculated masked occupancy, unassigned/empty/singleton populations, missing geometry, inclusive 150 m Euclidean distance, native-ID eligibility and relabeling invariance |
| `v2xsimtest.hooks.common.ResourceUsageRecorderTest` | Unequal intervals, same-time callbacks, geometry-only updates, final partial intervals, clipped histogram conservation, stable identities and selection/change counts, real attempt deduplication, header-only empty outputs and incremental flushing |
| `v2xsimtest.hook.invocations.AfterPacketFatesDeterminedInvocationTest` | Logical on-air provenance, including malformed values and zero-receiver events |
| `v2xsimtest.legacy.LegacySemanticDispatchTest` | Physical producer provenance for zero-receiver transmissions and later blocked events retaining a positive attempt number |
| `v2xsimtest.integration.ResourceUsageRunTest` | Native switch validation/composition, A–D resource masks, NR observer off/on equality with MRD diagnostics off/on and SensingBased, plus delay/loss/Gaussian output coexistence |

Run the focused gate in an open simulator project:

```matlab
addpath("tests")
names = ["v2xsimtest.resource.ResourceUsageTest", ...
    "v2xsimtest.hooks.common.ResourceUsageRecorderTest", ...
    "v2xsimtest.hook.invocations.AfterPacketFatesDeterminedInvocationTest", ...
    "v2xsimtest.legacy.LegacySemanticDispatchTest", ...
    "v2xsimtest.integration.ResourceUsageRunTest"];
parts = arrayfun(@testsuite,names,UniformOutput=false);
results = run([parts{:}]);
assertSuccess(results)
```

The checked-in `tests/+v2xsimtest/+fixtures/config/ResourceUsageNrStudy.toml`
copies the handoff's 1.2 s, 100-vehicle, 20 MHz NR fixture. It keeps all five
frequency resources and 16% of time resources: 80 selectable BRs out of 500.
Separate initialization probes check 80%, 20%, 16% and 15% time availability
without running statistical campaigns. SensingBased starts from a fresh
unresolved allocator branch. The paired runs explicitly use the same
`twister` generator and seed, compare native metrics, packet-fate records and
trajectories, and verify restoration of caller random state. With controller
diagnostics enabled they also compare every controller CSV, including live
assignments and allocation fingerprints. With diagnostics disabled, whole-run
committed assignments are not separately exported; their observation is covered
by the typed recorder fixtures and the diagnostic-enabled pair.

Study integration exposure is checked on `[0.2,1.1)` and must close at 1.2 s;
the tests do not invent startup coverage before the first committed allocation.
The recorder fixtures separately require coverage from time zero when an
assignment is supplied at zero. Interruption coverage is tested by inspecting
already-flushed intervals before successful cleanup, not by a mid-run engine
fault injection. No new toolbox dependency is introduced. These tests do not
establish long-duration PRR, d95, convergence or production readiness.

The metric helper preserves the subscript column passed to `accumarray` when
an unassigned singleton produces an empty selection. Recorder cleanup writes
typed empty change/transmission tables through the normal flush path; shared
column definitions keep empty and populated files consistent. Repeated cleanup
preserves both headers and existing rows. Additional regressions cover a run
with no callbacks and a singleton's complete unassigned interval.

The original four failing cases exposed these defects on source revision
`ea9322e2127c3ba1c21218f6e6d368ef7234ba67`. The source corrections keep those
assertions intact and introduce no allocator, geometry or radio-model changes.

Validation on MATLAB R2026a with the working-tree corrections based on that
source revision:

| Suite | Passed / total |
| --- | --- |
| `ResourceUsageTest` | 9 / 9 |
| `ResourceUsageRecorderTest` | 13 / 13 |
| `AfterPacketFatesDeterminedInvocationTest` | 5 / 5 |
| `LegacySemanticDispatchTest` | 4 / 4 |
| `ResourceUsageRunTest` | 8 / 8 |
| `v2xsimtest.positioning.PositionDelayErrorTest` | 8 / 8 |
| `v2xsimtest.positioning.PositionPacketLossErrorTest` | 14 / 14 |
| `v2xsimtest.positioning.IsotropicGaussianPositionErrorStatusEffectTest` | 11 / 11 |
| `v2xsimtest.positioning.PositionErrorDiagnosticsTest` | 5 / 5 |
| `v2xsimtest.resource.metrics.MaximumReuseTraceTest` | 7 / 7 |
| `v2xsimtest.resource.metrics.ControllerMetricsTest` | 12 / 12 |
| `v2xsimtest.hooks.common.ControllerDiagnosticsRecorderTest` | 5 / 5 |
| `v2xsimtest.integration.ControllerStateRunTest` | 1 / 1 |
| `v2xsimtest.resource.ConcreteAllocatorTest` | 20 / 20 |
| `v2xsimtest.resource.algorithm.AllocationKernelTest` | 12 / 12 |

All 134 distinct tests passed, with no failures or incomplete tests. Thirty-three
cases are newly added by the resource-usage work, including the three additional
cleanup/singleton cases accompanying the source corrections.
All nine simulations in the new NR integration suite completed successfully
(three off/on pairs and three impairment variants), each lasting 1.2 s.

The existing 0.45 s wrap regression remains separate from the 1.2 s NR study
fixture. `checkcode(file,"-id")` reports no findings on the eight added/modified
MATLAB files. The complete ordinary suite, publication campaigns, and timing
benchmarks were not run; allocation, mobility and radio algorithms and scientific
parameters are unchanged. The flushing tests establish output conservation across buffer
boundaries, not a performance bound for large populations.

## Long-running behavioral regressions

The controlled [density regression](../regression-tests/+v2xsimregression/+density/README.md)
holds geometry, motion, traffic, channel, and allocation settings fixed and
requires the paired 95% confidence interval for low-load minus high-load raw
PRR-AUC to be positive for LTE-V2X, NR-V2X, and IEEE 802.11p.

The [resource-pressure regression](../regression-tests/+v2xsimregression/+resourcepressure/README.md)
holds the NR-V2X PHY and workload fixed while reducing only the static
selectable-BR masks from 100% to 25% on both axes. It requires the paired 95%
confidence interval for unpressured-minus-pressured raw PRR-AUC to be positive
for every supported Mode 1 and Mode 2 allocator.

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
