# Exposed-reuse shadow evaluation

`missed_reuse` is an allocator-side candidate, not evidence of an exposed
terminal. It says that the live maximum-reuse-distance allocation separates a
UE pair that the same-state true-geometry oracle co-allocates. Geometry alone
cannot establish that the co-allocation is radio-safe.

The normal Ramp traces cannot reconstruct that safety result offline. Because
the pair did not co-transmit in the live allocation, those traces do not
contain the counterfactual endpoint-to-receiver powers, half-duplex schedule,
cross-technology interference, packet-error mapping, or complete receiver
roster for the proposed reuse. Reusing the oracle decision as a label would
therefore be circular.

## Shadow-case manifest

Create pending cases from `controller_reuse_candidate.csv` with:

```matlab
manifest = v2xsim.analysis.createExposedReuseShadowManifest( ...
    reuseCandidates, ...
    SourceRunId="seed-17/false-exit-magnitude-0p5", ...
    EvaluationHorizonSeconds=0.1, ...
    AllocationIntervalSeconds=0.1, ...
    AnalysisRangeMeters=300, ...
    MinimumReceiverObservationCount=10);
```

The input must include `SimulationTimeSeconds`, `AllocationEpoch`,
`NetworkSliceId`, canonical `FirstUeId` and `SecondUeId`, `CandidateType`, and
the live/oracle resource relations plus four endpoint resource columns
written by the controller diagnostic recorder. Only live
`separate_time`, oracle `cochannel` missed-reuse rows become cases; a pair
already concurrent on different live frequencies is not an exposed-terminal
opportunity.

Each output row is one allocation-epoch event. The control branch retains the
two live resources. In the intervention branch, both endpoints use the common
true-geometry-oracle resource while every non-endpoint live assignment remains
unchanged. This tests the oracle-proposed local reuse; an unsafe result does
not prove that no other co-allocation could be safe.

The intervention is half-open and ends no later than the next allocation
decision. It must not silently retain the pair's initial resource through
later controller decisions. To obtain the required observation count, restart
independent paired replications from the same fork rather than lengthening the
intervention. The manifest records
`InterventionPolicy=single_epoch_replicated_from_fork`,
`StopBeforeNextAllocationDecision=true`, the allocation interval, and the
required independent-replication count. A horizon longer than the allocation
interval is rejected.

The initial `OpportunityStatus` is always `shadow_run_required`. The manifest
also records that the executor must restore a complete pre-decision state,
replay the control branch, and use verified common random numbers. A common
seed alone is insufficient if the branches consume random draws in a
different order.

## Required branch executor

The simulator does not yet implement the state-fork executor. Such an executor
must:

1. snapshot all mobility, packet/HARQ, allocation, channel, interference, and
   component random-stream state immediately before the identified allocation
   decision;
2. reproduce the live decision and verify that the control replay matches the
   recorded source behavior;
3. restore the same snapshot, apply only the candidate-pair resource
   intervention, and run the configured single-epoch horizon;
4. enumerate the directed links from either candidate transmitter to every
   same-technology, non-endpoint receiver within the true analysis range at
   the fork;
5. repeat independently from the same checkpoint, retaining paired common
   random numbers within each control/intervention replicate, until every
   required directed link reaches its observation requirement;
6. record terminal `correct`, `error`, and `blocked` counts separately for
   every required transmitter-receiver link; and
7. prove that the receiver roster is complete and that the paired stochastic
   inputs were aligned.

The endpoint-specific link requirement prevents pooling a strong link from
hiding an unsafe weak link. After computing each directed-link PRR, the
reducer uses the worst endpoint-link PRR at each receiver.

## Strict reduction

Use:

```matlab
[classified, receiverPredictions, linkPredictions, summary] = ...
    v2xsim.analysis.reduceExposedReuseShadowResults( ...
        manifest, caseExecutions, receiverRoster, ...
        shadowReceiverCounts, ...
        MinimumPrr=0.9, PrrDefinition="delivery");
```

`caseExecutions` has these exact columns:

```text
ShadowCaseId
ExecutionStatus                 pending | complete | failed
StateSnapshotRestored
ControlReplayMatchedSource
CommonRandomNumbersVerified
ReceiverRosterComplete
```

`receiverRoster` has one row per required directed link:

```text
ShadowCaseId
TransmitterUeId
ReceiverUeId
IsSameTechnology
IsWithinAnalysisRange
```

`shadowReceiverCounts` has the same three identity columns followed by:

```text
CorrectCount
ErrorCount
BlockedCount
```

Delivery PRR uses `correct / (correct + error + blocked)`. Radio PRR can be
selected explicitly and uses `correct / (correct + error)`. Every eligible
directed link must meet the manifest's minimum observation count.

The case status is:

- `shadow_run_required` when no completed branch result exists;
- `invalid_shadow_run` when snapshot restoration, control replay, or
  common-random-number verification fails;
- `incomplete_receiver_coverage` when the receiver roster or observations are
  incomplete;
- `unsafe` when at least one receiver's worst directed-link PRR is below the
  safety threshold; or
- `exposed` (or `exposed_no_relevant_neighbors`) only after all completeness
  checks pass.

Unevaluated cases must remain pending. They must not be counted as zero exposed
opportunities.

When every sampled manifest row has a complete `exposed` or `unsafe`
classification, `summary` reports a Horvitz-Thompson exposed count and rate
using the manifest's `SelectionProbability` and `AnalysisWeight`. The known
denominator is the number of eligible temporal missed-reuse events before
case-limit sampling. If any sampled shadow case is pending, invalid, or
incomplete, the aggregate count and rate remain `NaN` with
`Status="IncompleteShadowEvaluation"`.

Repeated UE pairs are distinct events. The underlying
`classifyExposedReuseOpportunities` API supports `EventKeyVariables`; Ramp
analysis uses `AllocationEpoch` or the manifest's unique `ShadowCaseId`.
