# BR resource-allocation architecture

WiLabV2Xsim models cellular-sidelink beacon-resource (BR) allocation through a
single allocator lifecycle instead of selecting algorithms throughout the
simulation loop. This architecture currently applies to LTE-V2X and NR-V2X.
The IEEE 802.11p/ITS-G5 MAC and scheduler are outside this abstraction and
retain their existing behavior.

## Selecting an allocator

Set `resourceAllocation.Type` to one of the canonical string values below.
`ThreeGppAutonomous` is the default.

| Type | Category | Behavior |
|---|---|---|
| `ReuseDistance` | Centralized | Reuses resources subject to the configured minimum reuse distance. |
| `MaximumReuseDistance` | Centralized | Chooses reuse assignments that maximize distance between co-resource UEs. |
| `MinimumReusePower` | Centralized | Chooses reuse assignments that minimize estimated received reuse power. |
| `ThreeGppAutonomous` | Autonomous | Implements the current 3GPP sensing-based semi-persistent selection procedure for LTE Mode 4 and NR Mode 2. |
| `RandomBenchmark` | Benchmark | Selects packet-triggered resources randomly from the eligible set. |
| `OrderedBenchmark` | Benchmark | Assigns frequency-first resources in longitudinal-position order. |

`resourceAllocation.RandomSeed` seeds an allocator-owned random stream. Its
default is `simulation.RandomSeed`. Allocator randomness is stored as value
state, so copying an allocator does not make two allocator instances share a
mutable MATLAB random-stream handle.

The centralized algorithms use
`resourceAllocation.Controlled.ReassignmentIntervalSeconds`.
`ReuseDistance` additionally uses the controlled positioning-update,
position-error, and reuse-margin settings. `MinimumReusePower` can use
`resourceAllocation.Controlled.KnownShadowingEnabled`.
`ThreeGppAutonomous` uses the `resourceAllocation.Autonomous` settings.
`RandomBenchmark` uses the autonomous selection-window bounds but does not
implement the 3GPP sensing procedure. `OrderedBenchmark` has no
algorithm-specific parameters.

`MaximumReuseDistance` ranks reuse choices using the controller-visible
estimated distance matrix. Physical neighbor discovery and radio propagation
continue to use true geometry. When controller diagnostics are enabled, the
allocator also evaluates a one-step oracle with true distances from the same
pre-decision state and the same pre-generated random priorities; that oracle
is observational and never changes the live allocation.

The diagnostic comparison keeps two distinct pair graphs. The exact-resource
graph asks whether two UEs share one resource, while the interference-overlap
graph also includes adjacent-frequency resources in the same time slot.
Keeping both prevents a cochannel-to-adjacent oracle change from being
mistaken for removed interference and allows adjacent-channel placement
errors to be joined to causal PHY counterfactual evidence.

Partial frequency overlap and more than one transmission per packet are
supported only by `ThreeGppAutonomous` and `RandomBenchmark`.
`ThreeGppAutonomous` supports at most two transmissions.
It keeps resource identifiers in transmission order relative to the packet's
selection origin, preallocates every configured HARQ column even when DCC
temporarily permits fewer attempts, and validates only the attempts currently
required by the UE. NR re-evaluation never selects an already elapsed
resource occurrence: an acceptable reservation row is retained unchanged,
while an invalid member is replaced independently when possible.

## Contracts and lifecycle

Every allocator derives from `v2xsim.resource.ResourceAllocator`. The
simulation composes one allocator at initialization and drives the same
validated lifecycle for all algorithms:

1. `synchronizeUes` reconciles the allocator with entering and departing
   cellular-sidelink UEs.
2. `initialize` establishes the initial assignment state.
3. `step` advances allocation after a completed C-V2X transmission time
   interval.

The lifecycle accepts slice-qualified contexts and produces a
`ResourceAllocationResult` containing assignments, reservations, and the UEs
whose allocation changed. The base contract validates slice identity, UE
identity, resource bounds, and transmission count before committing a result.
The allocator owns its state; the simulator projects validated results into
the legacy transmission matrices at one integration boundary.

The two algorithm families differ in the information their contracts permit:

- `CentralizedAllocationContext` provides controller-wide position, distance,
  received-power, and shadowing observations.
- `AutonomousAllocationContext` provides UE-local eligibility and a
  `SensingSnapshot`. `ThreeGppAllocationContext` extends it with SPS,
  packet-state, and per-UE transmission-count facts. The only standards-based
  autonomous implementation today is `ThreeGppAutonomous`.

A concrete allocator declares its context contract and whether it consumes a
selection window. The legacy-array adapter dispatches on those capabilities,
not on allocator names; the named allocator factory is the only
algorithm-selection branch.

A shared sensing history is updated after every completed C-V2X transmission
time interval, regardless of the selected allocator. It supplies autonomous
selection and channel-busy-ratio measurements without embedding allocator
selection branches in sensing code.

## Network-slice scope

`BRResourceGrid` is an immutable time-frequency resource topology qualified by
a `NetworkSliceId`. Resource numbers are local to that slice: the same numeric
resource ID on two different slices does not identify the same resource.
Allocation contexts, sensing snapshots, histories, and results carry the same
slice identity, and mismatches are rejected.

The simulation runtime currently creates exactly one grid for
`NetworkSliceId("global")` and rejects multi-slice composition. Qualifying the
grid now keeps resource topology separate from global simulator state and
provides the boundary needed for future NR slices with independent numerology.
It does not yet enable multiple simultaneous slices or per-slice numerology.

## Coexistence boundary

Coexistence remains an integration concern around the cellular-sidelink
allocator. Coexistence logic supplies external eligibility or unavailable-slot
masks and shared sensing observations; it is not a separate allocator family.
Same-band coexistence mitigation currently requires
`ThreeGppAutonomous`. Other allocators can still be used where no such
same-band mitigation is active. The IEEE 802.11p/ITS-G5 scheduler is not routed
through `ResourceAllocator`.

## Migration from numeric algorithms

Numeric algorithm selection has been removed. Neither
`resourceAllocation.Algorithm` nor the legacy `BRAlgorithm` alias is accepted.
Use the named type corresponding to the historical implementation:

| Removed ID | `resourceAllocation.Type` |
|---:|---|
| `2` | `ReuseDistance` |
| `7` | `MaximumReuseDistance` |
| `10` | `MinimumReusePower` |
| `18` | `ThreeGppAutonomous` |
| `101` | `RandomBenchmark` |
| `102` | `OrderedBenchmark` |

Historical algorithm `9` is not available in the new contract. The
asynchronous-transmitter allocation options and the full-duplex allocation
algorithm/dynamic-threshold enhancements have also been removed. Full-duplex
radio and self-interference parameters that are not allocation-algorithm
selectors remain separate physical-layer settings.

## Output metadata

For simulations containing cellular-sidelink UEs,
`simulation_summary.json` stores allocator provenance under
`Configuration.ResourceAllocation.Metadata`. It records the canonical
allocator type, category, slice, independent random seed, grid dimensions and
slot duration, maximum transmission count, resolved type-specific options, and
context settings such as the SCI threshold and, where applicable, the
selection and sensing windows:

```json
{
  "Configuration": {
    "ResourceAllocation": {
      "Metadata": {
        "Type": "ThreeGppAutonomous",
        "Category": "Autonomous",
        "NetworkSliceId": "global",
        "RandomSeed": 7
      }
    }
  }
}
```

This keeps command-line overrides with the result and makes simulations
self-describing without depending on a numeric algorithm table.
