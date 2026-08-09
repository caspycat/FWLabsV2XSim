# Simulation output

Lessons 1, 4, 5, and 6 in the
[progressive V7 examples](../examples/README.md) demonstrate completion
summaries, position-error traces, optional artifacts, and isolated campaign
directories.

Each `v2xsim.runSimulation` invocation exclusively owns one run directory. The
`OutputDirectory` run option must name either a nonexistent directory or an
existing empty directory. The simulator never appends to, resumes, clears, or
overwrites a prior run directory.

At startup, the simulator atomically creates
`.v2xsim-output-lock` inside the run directory. A concurrent invocation, a
stale lock, or any other existing content causes the run to fail. The lock is
removed when the invocation exits, including after an error. Files left by a
failed run make that directory nonempty, so a new run must use a new
directory.

Campaign code must therefore use a separate child directory for every seed or
configuration:

```text
campaign/
  seed-10/
  seed-11/
```

## Live progress observations

`v2xsim.runSimulation` accepts an optional run-owned
`ProgressFcn=functionHandle`. The callback receives a scalar struct with:

- `Stage`: `initializing`, `simulating`, or `finalizing`;
- `SimulatedTimeSeconds` and `SimulationDurationSeconds`;
- `FractionComplete`;
- `ElapsedWallSeconds`;
- `Message`.

Simulated-time observations are throttled to approximately one-percent
increments. They are execution diagnostics, not scientific inputs, and do not
change the configuration or random streams. Callback failures stop the run
with `v2xsim:runtime:ProgressCallbackFailed`; the output-directory lease is
still released. Campaign runners can forward these observations through a
process-safe queue to an append-only progress journal.

## Completion summary

`simulation_summary.json` is written last. Its presence is the completed-run
signal; partial runs do not have a summary. The file is first serialized to a
temporary file in the same directory and then renamed into place. It is strict
JSON: nonfinite MATLAB values are represented as JSON `null`, while state
fields explain why a value is unavailable.

Schema version 2 is the current clean-break contract. Its root has three
sections:

```text
SchemaVersion
Run
Configuration
Results
```

The current completion-summary schema is version 2. Status-effect-backed
positioning modules are represented as generic inflictors with their concrete
effect type and effect options nested beneath them. Version-1 positioning
configuration artifacts are not translated into this representation.

`Run` records simulator provenance, the simulation random seed, durations,
the configuration file, and the user-supplied run label. `ConfigurationFile`
is the absolute TOML source when all file-authored leaves share one source; it
is empty for wholly programmatic or multi-file-derived configurations.
`Configuration` contains typed nested objects
for scenario, infrastructure, positioning, packet generation, resource pool,
radio channels, cellular sidelink, IEEE 802.11p, propagation, coexistence,
resource allocation, and awareness ranges.

Within `Configuration.Positioning.ErrorChain`, a status-effect-backed module
is represented as `Type="PositionErrorStatusEffectInflictor"` with a nested
`StatusEffect` object containing its concrete `Type` and normalized `Options`.
Direct modules such as `PositionDelayError` retain module-level options.

`Results` contains fixed `CellularSidelink`, `Ieee80211p`, and `Combined`
objects. Awareness results are arrays of disjoint range records. Each record
contains its lower and upper bounds, average neighbor count, the existing
snapshot-dispersion measure, nonblocked transmitter-receiver opportunity
count, blocking rate, error rate, and packet reception ratio. Channel-busy
ratio output uses explicit aggregate and per-channel statuses such as
`Available`, `Disabled`, `NoEligibleUes`, `InsufficientSamples`, and
`NoValidSamples`.

The schema deliberately has no numeric simulation identifier. A run is
identified by its directory and explicit provenance, not by an ID inferred
from a shared file.

## Optional artifact names

Optional files also have fixed per-run names:

```text
vehicle_kinematics.csv
average_neighbor_count_over_time_<technology>.csv
average_neighbor_count_simulation_wide_<technology>.csv
position_error_trace_<chunk>.csv
position_error_lifecycle_events.csv
controller_topology.csv
controller_rank_displacement.csv
controller_range_topology.csv
controller_allocation_decision.csv
controller_allocation_summary.csv
controller_co_user.csv
controller_reuse_candidate.csv
packet_fates_<chunk>.parquet
interference_attempts_<chunk>.csv
interference_counterfactuals_<chunk>.csv
per_vehicle_prr.csv
failure_mode_events.csv
failure_mode_evidence.csv
failure_mode_summary.csv
exposed_reuse_shadow_manifest.csv
packet_reception_ratio_<technology><packet><channel>.csv
packet_delay_<technology><packet><channel>.csv
update_delay_<technology><packet><channel>.csv
data_age_<technology><packet><channel>.csv
wireless_blind_spot_<technology>.csv
CBRstatistic_<technology><channel>.csv
CBRofGenericVehicle_<technology>.csv
coex_cv2xOnly_CBRstatistic_<technology>.csv
coexistence_technology_share.csv
error_log.txt
```

Technology tokens remain `11p`, `LTE`, and `5G` for packet and channel-load
outputs. Ordinary packets have no packet suffix; DENM uses `_DENM`. A
single-channel simulation has no channel suffix, while multichannel output
uses `_C<n>`. Average-neighbor-count output continues to use `all`, `cv2x`,
and `itsg5`.

The position-error, packet-fate, and interference-evidence traces are bounded
numbered chunks. `<chunk>` is a zero-padded six-digit sequence. Packet fates
can instead use CSV when `Outputs.PacketFateTrace.FileFormat` is `csv`; a run
never mixes the two packet-fate formats.

## Position-error trace

`position_error_trace_<chunk>.csv` contains one row per vehicle and
error module. It records the input and apparent X/Y coordinates, displacement
components and magnitude, module type, concrete `StatusEffectType`, module
order, the true route, selection and active-state flags, episode identity,
entry/exit/reset events, and whether an episode was already active at that
vehicle/module's first recorded observation. Such an episode is left-censored
even when that first observation is at simulation time zero. Vehicles with no
configured error module receive chain-level rows with `ModuleIndex` zero and
an empty `StatusEffectType`. This makes both the realized active-error
magnitude and each vehicle's observed status-effect lifecycle observable.

The semantic JSON summary records the exact applied error-chain order under
`Configuration.Positioning.ErrorChain`. Researcher-supplied entries contain
`Origin="Custom"`, their full MATLAB class name in `Type`, and the JSON-safe
caller descriptor. The in-memory `SimulationResult.AppliedPositionErrorChain`
contains the same value. Reproducing such a run also requires the referenced
research code; the resolved TOML configuration contains only built-in module
parameters.

The Ramp study reducer also writes
`position_error_lifecycle_events.csv`. It is a compact, sorted projection of
the full trace containing only evaluation, selection, active-segment
entry/exit, reset, and censoring event rows. It retains the vehicle, time,
module, concrete status-effect type, true route, episode, selected/active
state, and individual event flags so status-effect activation and deactivation
times can be consumed without scanning every position sample. If an episode
remains active in a vehicle/module's final trace row, the reducer appends a
terminal row with
`RightCensoredAtEnd=true` and `LifecycleEvent="RightCensoredAtEnd"`. This is an
observation-window boundary, not an `ActiveSegmentExited` event and not
evidence that the status effect was deactivated.

The seed summary reports `StatusEffectEpisodeCount`,
`LeftCensoredEpisodeCount`, and `RightCensoredEpisodeCount`, keyed by vehicle,
module, concrete status-effect type, and episode. The numbered position trace
remains authoritative. Ramp seed results also include
`SelectedVehicleCohortKey`, a sorted stable-identity key used to enforce exact
Gaussian-versus-false-route cohort, active-sample, and episode matching within
route.

## Controller diagnostics

Controller diagnostics are emitted only for maximum-reuse-distance
allocations. Every row carries `SimulationTimeSeconds`, `AllocationEpoch`,
`AbsoluteSlot`, and `NetworkSliceId`. An allocation epoch increments only
when the allocator makes a decision.

- `controller_topology.csv` contains per-ego normalized Kendall inversion
  distance, mean and maximum rank displacement, and top-k neighbor Jaccard.
- `controller_rank_displacement.csv` contains every ego-neighbor true and
  apparent rank pair only when
  `Outputs.ControllerDiagnostics.RankDisplacementEnabled` is `true`. It is
  disabled by default because its row count is O(N²) per allocation epoch.
- `controller_range_topology.csv` contains true/apparent counts, missed and
  phantom counts, and set Jaccard at each configured awareness range.
- `controller_allocation_decision.csv` contains the live decision trace, the
  same-state true-geometry oracle decision, decision agreement, churn, and
  true-distance objective/regret evidence.
- `controller_allocation_summary.csv` contains exact-resource and time-slot
  disagreement, label-invariant resource/time pair-graph XOR and Jaccard,
  churn, true co-resource-distance summaries, and separate harmful/missed
  candidate counts and rates over all unordered UE pairs. It also reports
  XOR, Jaccard, and directional counts/rates for the physical interference-
  overlap graph. The production recorder uses the simulator's frequency-
  coupling matrix, so nonzero farther-channel in-band emission is included
  as well as cochannel and adjacent-frequency coupling. These rates retain
  zero-candidate epochs without requiring dense pair output.
- `controller_co_user.csv` contains per-UE live/oracle co-user counts and
  co-user Jaccard.
- `controller_reuse_candidate.csv` is sparse: it contains unordered pairs
  whose exact-resource relation or interference-overlap relation changes.
  `CandidateType` retains exact-resource semantics: `harmful_reuse` shares a
  live resource but not an oracle resource, while `missed_reuse` shares an
  oracle resource but not a live resource. Explicit
  `LiveResourceRelation`/`OracleResourceRelation` values distinguish
  `unassigned`, `separate_time`, `cochannel`, `adjacent_channel`, and
  `other_same_time`; directional flags identify PHY-coupling-aware
  interference-overlap changes.
  Consequently a live adjacent-channel pair that the oracle separates is
  retained even though its exact-resource `CandidateType` is
  `unchanged_separation`. A header-only file is retained when an entire run
  has no candidates. These rows identify allocation candidates, not proven
  radio causality.

The true-geometry oracle is evaluated from the same pre-decision allocator
state and the same pre-generated random priority plan. It does not mutate the
live allocator and is deliberately a one-step counterfactual, not an
independent closed-loop simulation.

Seed-level Ramp summaries average controller diagnostics over all eligible
egos, pairs, and decision epochs, representing total network impact.
Active-conditioned secondary summaries are not emitted as formal paired
effects because the no-error arm has no matched active cohort. They can be
reconstructed by carrying `position_error_trace_<chunk>.csv` state forward
to controller time and joining stable UE IDs; for a module chain, first
aggregate activity with `any(IsActive)` per vehicle and time.

## Directed packet-fate trace and PRR

`packet_fates_<chunk>.parquet` contains one terminal directed
transmitter-packet-receiver fate. Stable UE IDs and per-transmitter packet
sequences survive row reordering and vehicle-slot reuse. The trace also
contains generation/fate time, attempt number, channel, packet type, true
distance, resource coordinates, and allocation epoch.

Allocator-side `blocked` observations are held until the packet advances or
the run ends. A later radio `correct` or `error` outcome for the same directed
packet supersedes the provisional block. Thus each directed packet
opportunity contributes exactly one terminal fate:

```text
delivery PRR = correct / (correct + error + blocked)
radio PRR = correct / (correct + error)
blocking rate = blocked / (correct + error + blocked)
```

The fixed-grid normalized PRR-AUC inserts the explicit anchor `(distance 0,
PRR 1)`, integrates the retained bins through the configured maximum
distance, and divides by that maximum distance. Empty distance bins remain
missing and make the AUC incomplete; they are not silently dropped.

For a publication-style PRR range, first pool terminal counts across
replications with `v2xsim.analysis.poolPacketReceptionCounts`, then call
`v2xsim.analysis.prrThresholdRange`. Its default threshold is 0.9, matching
the archived PRR-range papers; `Threshold=0.95` requests the corresponding
95-percent range. The helper adds the explicit synthetic `(0 m, 1)` anchor
and returns the first linearly interpolated downward crossing plus an
explicit `Crossed`, `LeftCensored`, or `RightCensored` status. It does not
average per-run ratios, which would give short and long runs equal weight.
If any configured distance bin is empty, it returns `NaN` with
`IncompleteDistanceGrid` rather than inferring a range from sparse data.

The Ramp error-structure reducer reads packet-fate chunks incrementally and
writes `per_vehicle_prr.csv`.
It contains transmitter and receiver perspectives for each stable vehicle
identity, split into `all`, `active`, and `inactive` position-error states.
For a chained error model, an endpoint is active when any module is active at
the most recent position observation at or before its packet-fate time.
It reports pooled terminal counts and ratios, delivery/radio AUC with
completeness status, selected/active lifecycle counts,
`StatusEffectEpisodeCount`, and first/last active time. Sparse vehicle-level
AUCs remain missing while their pooled counts and PRR are retained.

Hidden-terminal labels require terminal-attempt PHY counterfactual evidence:
the observed SINR must fail the sampled decode threshold, removing an
individual interferer must make it pass, and that interferer pair must be a
harmful interference-overlap allocator candidate at the matching allocation
epoch. The allocator's live relation must also equal the PHY evidence's
`ResourceRelation`. Cochannel, adjacent-channel, and farther same-time
in-band-emission placement errors can therefore be hidden terminals when the
recorded PHY coupling is removed by the oracle allocation. Allocation overlap
alone is not classified as a hidden terminal. The PHY evidence is not yet
slice-qualified, so this join explicitly accepts only the simulator's single
`global` network slice.

When `Outputs.InterferenceClassification.Enabled` is true,
`interference_attempts_<chunk>.csv` records terminal error attempts, their
observed SINR, sampled decode threshold, the SINR after removing all
attributed C-V2X interferers, contributor count, and whether the attribution
is exhaustive. `interference_counterfactuals_<chunk>.csv` has one row per
nonzero attributed interferer, including stable identities, allocation
epoch, resource relation, removed power, and the SINR after removing only
that source. Aggregate cross-technology interference is not assigned a fake
UE identity, so affected rows are explicitly non-exhaustive.

The Ramp reducer joins those chunks to terminal packet fates by stable
directed generation identity and attempt, then joins live/oracle allocation
evidence by allocation epoch and canonical UE pair. It writes:

- `failure_mode_events.csv`: one row per terminal radio error, with failure
  mode, culprit IDs, evidence coverage, transmitter/receiver status-effect
  activity, and true route at the fate time. It also records whether a
  schema-valid allocator candidate artifact was available;
- `failure_mode_evidence.csv`: a sparse joined convenience artifact retaining
  only individually sufficient interferers and harmful interference-overlap
  candidates, including the matched allocator/PHY relation flag. It is
  header-only when no such rows exist; the raw numbered counterfactual chunks
  remain authoritative for joint-interference and incomplete-evidence
  reconstruction; and
- `failure_mode_summary.csv`: detected and analyzable counts, composition
  rates over all terminal errors, incidence rates over `correct + error`
  terminal radio fates, their explicit denominators and analyzability
  statuses, status-effect-active transmitter/receiver/either-endpoint counts,
  and allocator/interference-evidence availability. `RateAmongErrors` and
  `RateAmongTerminalRadioFates` are explicit aliases for composition and
  incidence.

Missing or non-exhaustive evidence remains an explicit unclassified mode.
Only exhaustive absence of a sufficient attributed interferer can be called
noise or propagation. A missing or legacy controller-candidate schema
produces `IncompleteAllocatorEvidence`; a valid header-only candidate artifact
means allocator evidence was available and the run had zero candidates.
Primary causal rates are `NaN` with a `NotAnalyzable...` status until the
required evidence is complete. Hidden-terminal counts and rates additionally
require allocator overlap evidence, so unavailable allocator evidence is
never represented as a hidden count of zero. `DetectedCount` preserves the
raw classifier observation for diagnostics. The hidden-terminal row uses the
causal `IsHiddenTerminal` flag and may overlap an assigned ambiguous mode such
as `multiple_sufficient_interferers`.
Accordingly, `CompositionRate` is a mode-specific prevalence among errors,
not a mutually exclusive partition, and mode rates need not sum to one. The
current hidden definition requires at least one individually sufficient
allocator-induced interferer; jointly sufficient harmful subsets without an
individually sufficient member remain `joint_interference`.

An exposed-terminal label requires a live separate-time, oracle-cochannel
missed-reuse pair and a complete shadow prediction for all relevant
same-technology receivers. Exact missed-reuse pairs already concurrent on
different live frequencies are excluded. Candidate pairs without an explicit
prediction remain unclassified rather than being treated as safe reuse
opportunities.
The Ramp reducer always writes `exposed_reuse_shadow_manifest.csv`, including
a header-only manifest when there are no missed-reuse candidates. Nonempty
rows are pending replay cases, not exposed-terminal labels. See
`docs/exposed-reuse-shadow-evaluation.md` for the required branch executor and
strict reducer contract.

`coexistence_technology_share.csv` has the stable columns
`SimulationTimeSeconds`, `VehicleId`,
`CellularSidelinkOnlyChannelBusyRatio`, `CombinedChannelBusyRatio`,
`CellularSidelinkVehicleFraction`, and
`AllocatedCellularSidelinkSubframeCount`.

Archived simulation tasks under `old_src/codeForPaper` use the JSON summary as
their completed-run marker, and their paper-analysis readers use the fixed CSV
names above. Old debug plotting scripts retain historical numbered XLS input
filenames for provenance; they are not supported V7 output readers. Current
tests, examples, and regression runners consume the JSON summary and
suffixless CSV artifacts.
