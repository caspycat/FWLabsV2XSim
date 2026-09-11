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
Direct modules such as `PositionPacketLossError` and `PositionDelayError`
retain module-level options.

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
controller_state.csv
controller_topology.csv
controller_rank_displacement.csv
controller_range_topology.csv
controller_allocation_decision.csv
controller_allocation_summary.csv
controller_co_user.csv
controller_reuse_candidate.csv
resource_usage.csv
resource_occupancy.csv
resource_changes.csv
resource_transmissions.csv
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

## Resource-usage evidence

Enable the optional cellular sidelink observer with
`Outputs.ResourceUsage.Enabled=true` (default `false`). It supports the study's
single `global` slice and one transmission per packet, including
`MaximumReuseDistance` and `SensingBased`, independently of controller
diagnostics. It observes committed assignments, true X/Y geometry and actual
transmitter attempts.

`resource_usage.csv` describes positive-length assignment/geometry intervals;
`resource_occupancy.csv` gives the matching distribution of users per selectable
resource, including unused resources. Clip intervals to the measurement window
and weight by elapsed seconds. Masked resources never contribute to the unused
count. Unassigned vehicles remain in `VehicleCount`, even for a singleton; they
add no occupied resources or sharing pairs.

`resource_changes.csv` separates actual continuing-vehicle assignment changes
from selections and allocator blocks. `resource_transmissions.csv` records one
row per actual attempt, independent of receiver count. Successful recorder
cleanup writes both event files even when they have no rows: the normal column
headers identify supported recording with no activity. Repeated cleanup does
not duplicate headers or previously written rows. No artificial event or
assignment exposure is added to fill an empty stream. These CSVs are not a
completion signal; use `simulation_summary.json` to identify completed runs.

The [resource-usage contract tests](testing-v7.md#resource-usage-observer-contracts)
cover the schemas, empty streams, identity, geometry, time weighting and short
NR integrations.

## Packet delay and data age

Packet delay measures the successful reception time minus **that packet's
original generation time**. It includes waiting in the packet buffer, channel
access, and any elapsed unsuccessful attempts before reception. Queue admission,
head selection, and retries never rewrite the generation timestamp. The existing
coexistence adjustment from application generation to access-layer admission is
also preserved.

Data age records reception-sampled **peak age**: the current successful reception
time minus the generation time of the previously successfully received packet
on that directed link and awareness range. The first success establishes history
without recording an age sample. Failed and blocked packets do not supply a new
generation timestamp. This is not a time-averaged age measurement. Both metrics
therefore include buffering time through their generation timestamps; for example,
generation at 0 s and reception at 0.35 s yields 0.35 s packet delay even if
transmission started at 0.30 s.

Packet-delay CSVs retain their columns and configured bin width, but now grow
beyond the original approximately two-allocation-period extent when a successful
reception has a longer delay. Consumers must read the row count from the file.
Counts already recorded in other technologies, channels, and packet types are
preserved when the histogram grows. Blocked/error outcomes do not extend it.
Data age retains its existing maximum-age allocation and final overflow bin.

Packet sequences are assigned at generation per stable UE, including packets
that are subsequently dropped, and survive retries and departure/re-entry of the
same identity. Fate rows are in reporting order, which need not be packet-sequence
order: a waiting packet can be dropped while an older packet is on air. The hook
transmitter metadata includes logical `IsPacketComplete`; true requires an
explicit sequence and retires the packet's reconciliation state after processing
that invocation. No further observations may be emitted for a completed packet.
Departure completion notifications contain no receiver fates and add no PRR counts.

IEEE 802.11p summary counters now commit the same first-success and final-error
events as PRR and packet-fate outputs. A failed intermediate copy is not counted
as a terminal error. This corrects historical overcounts when a simulation ended
with a packet awaiting repetition; overflow after an attempted packet commits
errors only for receivers that have not already received it. Consequently, runs
with unfinished repetitions can deliberately differ from archived summary counts.

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

The final three columns describe network-update provenance:
`NetworkUpdateOutcome`, `OutputSourceTimeSeconds`, and `OutputAgeSeconds`.
Packet loss reports `BootstrapReceived`, `Received`, or `Dropped`; fixed delay
reports `Delayed`, `WarmupHeld`, or `CurrentFallback`. Source time is the
module-local time at which the emitted upstream sample was captured, and age
is current simulation time minus that source time. These ages are not additive
or end-to-end when more than one network module is chained. Non-network and
chain-identity rows use an empty outcome and `NaN` times.

These position-error fields describe the abstract controller-bound update
path. They are independent of PHY packet fates and the application-packet
latency histogram controlled by `Outputs.PacketDelay`.

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

- `controller_state.csv` contains one row for every active allocator UE at
  each recorded allocation epoch, including UEs retaining an assignment.
  `UeId`, `EstimatedXMeters`, `LiveResourceId`, and `OracleResourceId` preserve
  identity, consumed apparent longitudinal position, and live/immediate-shadow
  assignments. `NearestTrueCoResourceMeters` and `NearestTrueSameSlotMeters`
  use the context's true pairwise geometry; the latter includes all frequencies
  in the same slot. Both exclude self and are `Inf` when no co-user exists.
  `RandomPlanFingerprint` repeats the epoch's complete random-priority digest.
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

`evaluateMaximumReuseDistanceTrace` accepts an optional `EligibilityMask`,
whose rows follow `AssignmentsBefore` and whose columns are local resource
IDs. Omission or a 0-by-0 mask means all resources are eligible. Each UE must
have at least one eligible resource, and every selected ID must be valid and
eligible. Resource ranks, time-slot ranks, and regret exclude unavailable
alternatives. Occupants on any frequency still affect an eligible slot's
quality. An unavailable empty slot cannot cause infinite regret; a genuinely
eligible empty slot can. Tied infinite best/selected scores have zero regret.
Invalid masks raise `v2xsim:resource:metrics:InvalidEligibility`; invalid or
unavailable selections raise `v2xsim:resource:metrics:IneligibleSelection`.

`RandomPlanFingerprint` is lowercase SHA-256 of the concatenated
`DecisionPriority(:)`, `TimePriority(:)`, and `FrequencyPriority(:)` arrays,
serialized as little-endian IEEE-754 doubles in column-major order. It includes
priorities for all allocator UEs, including those not deciding in this epoch.
The live replay must reproduce committed assignments and decision UE rows
before its plan is shared with the oracle. Hashing consumes no random draws.
Compare fingerprints together with the ordered UE identities, grid dimensions,
and epoch keys: the digest encodes priorities, not those contextual keys.
It provides allocator-pairing evidence, not identical channel samples or a
standalone reconstruction of the plan. MATLAB's JVM is required for this
diagnostic hash; no additional toolbox is required. Runs with diagnostics
disabled do not require this hashing capability. Imported diagnostic payloads
without a fingerprint retain a blank field, which provides no pairing evidence.

To join consumed inputs to source timestamps, carry the final module's
`position_error_trace_<chunk>.csv` output forward by stable vehicle identity
to `SimulationTimeSeconds`, then join by UE and slice. Inspect
`OutputSourceTimeSeconds` and `OutputAgeSeconds` for the relevant network
module: these are module-local input timestamps, not end-to-end ages through
an arbitrary module chain. `EstimatedXMeters` records the consumed position,
so a coordinate wrap must not be mistaken for an identity change. Custom
re-entry episode policies belong to the research positioning module; the
controller recorder does not invent episode keys or reset native histories.

Seed-level Ramp summaries average controller diagnostics over all eligible
egos, pairs, and decision epochs, representing total network impact.
Active-conditioned secondary summaries are not emitted as formal paired
effects because the no-error arm has no matched active cohort. They can be
reconstructed by carrying `position_error_trace_<chunk>.csv` state forward
to controller time and joining stable UE IDs; for a module chain, first
aggregate activity with `any(IsActive)` per vehicle and time.

## Directed packet-fate trace and PRR

`packet_fates_<chunk>.parquet` contains terminal directed
transmitter-packet-receiver PRR observations. Stable UE IDs and
per-transmitter packet sequences survive row reordering and vehicle-slot
reuse. The trace also contains generation/fate time, attempt number, channel,
packet type, true distance, resource coordinates, and allocation epoch.

Allocator-side `blocked` observations are immutable terminal events and are
written immediately for the same PRR-eligible receiver set counted by the
global recorder. For a blocked row, `TrueDistanceMeters` is the true-distance
snapshot at the allocation/block event. For a radio `correct` or `error` row,
it is the true distance at the radio-fate event. Radio-attempt reconciliation
does not replace, delay, or re-emit blocked rows:

```text
delivery PRR = correct / (correct + error + blocked)
radio PRR = correct / (correct + error)
blocking rate = blocked / (correct + error + blocked)
```

Packet-fate traces produced before this blocked-event correction can be
missing blocked rows. Regenerate those traces before using them for exact
reconciliation with global PRR counts.

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
