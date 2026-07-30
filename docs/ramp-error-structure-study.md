# Ramp position-error structure study

This workflow answers whether the *structure* of position error changes the
maximum-reuse-distance controller more than its mean magnitude. It treats
Gaussian displacement, false exit, and false merge as three positioning
status effects and uses the same traffic, radio, packet-generation, allocator,
and vehicle-selection seeds in corresponding arms. This is seed pairing, not
a guarantee that every downstream random draw remains aligned after schedules
diverge.

The campaign entry point is:

```matlab
addpath("src");
addpath("regression-tests");

[seedResults, effectAnalysis, effectSeedResults, ...
    routeAnalysis, routeEffectSeedResults] = ...
    v2xsimregression.positionerror.runRampErrorStructureCampaign( ...
        string(pwd), "/tmp/ramp-error-study", ...
        RandomSeeds=10:29, ...
        NormalizedMagnitudes=[0.25, 0.5, 1]);
```

The campaign uses every worker exposed by the local `Processes` profile by
default. Specify a finite `MaxWorkers` value only when an explicit resource cap
is required; `ExecutionMode="serial"` disables pool creation.

The runner loads
`tests/+v2xsimtest/+fixtures/config/ExitRampHighwaySmoke.toml` as its declarative
baseline and applies nested, typed configuration patches for each treatment.
The run label and output directory remain runtime options rather than
configuration data.

The output root must be new or empty. Every work item receives its own run
directory and completion summary. The runner writes
`campaign_manifest.csv` before dispatch. It writes `seed_results.csv`
immediately after reduction and magnitude-calibration columns are added, so
completed diagnostics remain available even if a later manipulation check
or primary analysis fails. The manifest records `SelectionRandomSeed` for
cohort selection and `DisplacementRandomSeed` for Gaussian displacement; the
two mechanisms use separate component-owned random streams. A successful
campaign also writes
`effect_seed_results.csv`, `effect_analysis.json`,
`route_stratified_effect_seed_results.csv`,
`route_stratified_effect_analysis.json`,
`mechanism_effect_seed_results.csv`, and
`mechanism_effect_analysis.json`.

The status-effect field names are a clean study-schema boundary. Reducers do
not translate earlier Ramp study tables; regenerate all campaign artifacts
with the current simulator before combining runs.

## Experimental design

Each seed has one no-error baseline and four execution treatments at every
magnitude:

| Execution treatment | Scientific error model | Eligible route population |
|---|---|---|
| `GaussianMainline` | Gaussian | `Merge` and `Adjacent` |
| `GaussianRamp` | Gaussian | `Ramp` |
| `FalseExit` | False exit | `Merge` and `Adjacent` |
| `FalseMerge` | False merge | `Ramp` |

The two Gaussian executions enable route-fixed comparisons: Gaussian versus
false exit on the mainline population, and Gaussian versus false merge on the
ramp population. Their route-specific baseline deltas are also averaged with
equal weight to form one descriptive Gaussian result. False exit still occurs
only on the mainline population and false merge only on the ramp population,
so the combined three-model result does not identify a route-independent
three-way structure effect.

`effect_seed_results.csv` keeps `DeliveryPrrAuc` as an observed quantity:
the equal-route-weight raw AUC for Gaussian, the mainline AUC for false exit,
and the ramp AUC for false merge. Its explicit `DeltaDeliveryPrrAuc` column
contains the corresponding paired, route-matched treatment effect. Keeping
these separate prevents a route-specific delta from being added to an
unrelated common baseline, which could otherwise manufacture a value outside
the physical AUC interval `[0, 1]`. Effect analysis uses the explicit delta;
ordinary result tables without that column retain the baseline-subtraction
behavior.

The runner's primary identifiable analyses are two within-route factorials.
Mainline compares
Gaussian with false exit; ramp compares Gaussian with false merge. These are
the cleanest structure-versus-magnitude contrasts because error structure
varies while the route population is fixed. The combined three-model,
route-balanced result is a predeclared scenario-level description. It must
not be used by itself to claim that one of all three structures dominates,
because route-specific effect modification is not identified.

The long mechanism table applies the same three estimands to each selected
scalar outcome. `RouteBalanced` compares an equal-weight mean of the
Gaussian-mainline and Gaussian-ramp paired deltas with false exit and false
merge. `Mainline` compares Gaussian-mainline with false exit, while `Ramp`
compares Gaussian-ramp with false merge. It records the raw response,
baseline response, and explicit paired delta separately.

For road length \(L\), lane width \(w\), and merge length \(M\), the mean
active full-scale false-route displacement under uniform post-fork sampling
is

\[
\bar e_{\mathrm{route}} = \frac{L}{4} +
    w\left(1-\frac{M}{L}\right).
\]

For normalized magnitude \(m\), the target mean is
\(m\bar e_{\mathrm{route}}\). False-route displacement is multiplied by
\(m\). The Gaussian X and Y components use

\[
\sigma = m\bar e_{\mathrm{route}}\sqrt{\frac{2}{\pi}},
\]

so their Rayleigh-distributed radial error has the same target mean.
Calibration matches the mean, not the RMS, 95th percentile, temporal
correlation, direction, or tail shape; those differences are part of error
structure and are recorded rather than normalized away.

The campaign uses one-attempt C-V2X packets, a fixed reservation and
reassignment interval, and maximum reuse distance. This makes a terminal
radio error attributable to one sampled attempt while retaining allocator
blocking as a separate outcome.

## Manipulation checks

Every arm must first be checked for:

- realized mean active displacement versus `TargetMeanMagnitudeMeters`;
- overall mean displacement and active vehicle-time fraction;
- active sample count and selected-vehicle count;
- exact selected-cohort identity and active sample/episode matching between
  Gaussian and false-route arms on the same route;
- RMS and 95th-percentile displacement;
- `StatusEffectEpisodeCount` and left/right censoring;
- route-specific vehicle exposure and time spent active.

The analytic false-route mean assumes uniform sampling over the active
post-fork segment. `RealizedMeanErrorMagnitudeMeters` is therefore the
campaign's definitive equality check. A material mismatch is a failed
manipulation check, not an error-structure result. By default the runner
requires every nonbaseline arm to be within 5% of its target
(`MaximumMagnitudeRelativeError=0.05`) and stops before effect analysis when
that check fails. The tolerance and the explicit
`EnforceMagnitudeCalibration` switch are recorded choices and should be set
before examining outcomes. `RealizedNormalizedMagnitude` is propagated into
every effect table. Each analysis JSON contains a nested
`RealizedMagnitudeSensitivity` fit that uses it as a continuous covariate
while retaining assigned magnitude only as the balanced treatment-cell key.

`SelectedVehicleCohortKey` records the sorted stable identities selected in
each run. The campaign pairs `GaussianMainline` with `FalseExit` and
`GaussianRamp` with `FalseMerge` at each seed and magnitude, then requires
the cohort key, active position-sample count, and episode count to agree
exactly. `EnforceExposureMatching=true` is the default; a mismatch stops the
campaign before effect analysis and remains visible in `seed_results.csv`.

## Mechanism metrics

The study follows a causal chain:

```text
position error
  -> apparent neighbor topology
  -> maximum-reuse allocation
  -> terminal radio/blocking outcomes
  -> delivery and radio PRR-AUC
```

The predeclared scalar mechanism outcomes are:

- mean normalized Kendall distance and top-k neighbor Jaccard;
- resource and PHY-coupling-aware interference-overlap pair-graph XOR
  rates, plus exact-decision disagreement rate;
- true-distance regret;
- harmful/missed exact-reuse and physical-interference-overlap candidate
  rates;
- composition and incidence rates for hidden terminal, half duplex,
  cochannel, adjacent-channel, cross-technology,
  multiple-sufficient-interferer, joint-interference, other-interference,
  and noise/propagation modes; and
- radio PRR-AUC.

For a mode count \(n_m\), the two failure-rate denominators are fixed:

```text
composition rate = n_m / all terminal errors
incidence rate = n_m / (correct + error terminal radio fates)
```

Blocked allocator outcomes are excluded from the incidence denominator
because no terminal radio attempt occurred. Composition describes how the
error mixture changes; incidence describes how often the mechanism occurs
among radio fates. Both should be reported because a treatment can change the
number of errors as well as their composition.

Each outcome has a separate status for the route-balanced, mainline, and ramp
estimands in `mechanism_effect_analysis.json`. A nonfinite outcome, such as a
composition rate in a seed with no terminal errors, is `NotAnalyzable`; it
does not abort the primary delivery-PRR campaign. Causal failure rates are
also nonfinite when interference evidence is incomplete, and hidden-terminal
rates additionally require schema-valid allocator overlap evidence.
Scientifically degenerate factorials are also retained with that status
rather than being reported as zero effects.

The status-effect-active endpoint AUC has no matched active population in the
no-error arm. `EitherEndpointStatusEffectActiveDeliveryPrrAuc` therefore
remains descriptive in
`seed_results.csv` and `per_vehicle_prr.csv`, but is excluded from formal
paired mechanism inference. It must not be paired with the baseline arm's
overall AUC as though those link populations were interchangeable.

### Apparent topology

For each ego UE, other UEs are ranked by true and apparent distance. Ties are
resolved by stable UE identity. With \(q\) other UEs, normalized Kendall
distance is the inversion count divided by \(\binom{q}{2}\). Zero means the
rankings agree; one means complete reversal.

Kendall distance should not be used alone. The compact trace also records:

- mean and maximum rank displacement per ego;
- top-k neighbor-set Jaccard;
- missed and phantom neighbor counts at every awareness range;
- range-specific neighbor-set Jaccard.

These distinguish a harmless reorder among distant vehicles from a topology
change at the controller's relevant neighborhood boundary.
Set `Outputs.ControllerDiagnostics.RankDisplacementEnabled=true` only when
the O(N²)-per-epoch signed and absolute ego-neighbor rank detail is required.
Seed-level controller scalars pool all eligible egos and decision epochs.
That is the total-network-impact estimand and includes spillovers onto
vehicles without an active status effect, but it can dilute a localized
effect. For a descriptive active-only decomposition, carry the latest
position state forward to each controller time, aggregate chained modules
with `any(IsActive)` per vehicle/time, and join by stable ego or pair IDs.
Keep this secondary: activity is treatment-defined and the no-error arm has
no matched active cohort.

### Allocation difference

The live maximum-reuse decision uses apparent distances. A true-geometry
oracle runs from the same pre-decision assignment state with the same
pre-generated random priorities. Comparison includes:

- exact resource and time-slot disagreement;
- assignment churn;
- label-invariant resource/time pair-graph XOR and Jaccard;
- a physical-overlap pair graph driven by the simulator's frequency-
  coupling matrix, including any nonzero farther-channel in-band emission
  within the same time slot;
- per-UE co-user Jaccard;
- live versus oracle nearest true co-user distance;
- true-distance objective regret and decision margins;
- sparse pairs whose exact-resource or physical-overlap relation changes,
  plus directional counts and all-pair rates in every allocation-summary
  epoch.

Resource IDs are arbitrary labels, so pair-graph metrics are the primary
measure of a meaningfully different allocation. `CandidateType` retains
exact-resource semantics for exposed-reuse selection, while explicit
live/oracle relations and overlap flags carry the cochannel/adjacent
interference meaning used by hidden-terminal attribution. The oracle is a
one-step counterfactual; it does not claim to represent later closed-loop
divergence.

### Packet outcomes and status-effect-active vehicles

The directed packet-fate trace keeps stable transmitter and receiver UE IDs,
packet sequence, generation time, attempt, resource, allocation epoch, true
distance, and one terminal outcome. It supports transmitter-, receiver-, and
either-endpoint views of status-effect-active vehicles at the fate time.

Each completed work item also writes `per_vehicle_prr.csv`, with transmitter
and receiver perspectives split into `all`, `active`, and `inactive`
position-error states. Use its terminal counts and completeness status to
identify status-effect-active vehicles; a missing vehicle-level AUC is
expected when that vehicle has no observations in one or more fixed distance
bins.
When error modules are chained, an endpoint is active if any configured
module is active at the latest position observation at or before the packet
fate.
`position_error_lifecycle_events.csv` is the compact event-only view of
status-effect evaluation, selection, activation, deactivation, reset, and
observation-boundary censoring. It retains both the generic `ModuleType` and
the concrete `StatusEffectType`. An episode active at its first vehicle/module
observation is left-censored, including when that observation occurs at
simulation time zero. An episode still active at its final observation
receives a distinct `RightCensoredAtEnd` terminal row; this row must not be
interpreted as status-effect deactivation. `seed_results.csv` carries the
corresponding
`LeftCensoredEpisodeCount` and `RightCensoredEpisodeCount`. The full numbered
position trace remains the authoritative sample-level record.

Delivery PRR and radio PRR answer different questions:

```text
delivery PRR = correct / (correct + error + blocked)
radio PRR = correct / (correct + error)
```

Always pool fate counts before dividing. Never average seed, bin, or
per-vehicle PRR ratios with unequal denominators.

### Hidden and exposed terminals

A hidden terminal requires all of the following evidence at the terminal
attempt:

1. the observed SINR is below the sampled decode threshold;
2. removing an individual interferer raises SINR to that threshold;
3. the interferer is on a same-time frequency with nonzero PHY coupling,
   whether cochannel, adjacent, or farther-channel in-band emission; and
4. allocator evidence marks a harmful interference-overlap transition, and
   its live resource relation matches the PHY relation.

The overlap transition, rather than `CandidateType` alone, is the causal
allocator condition. In particular, moving a pair from cochannel live
placement to adjacent-channel oracle placement does not resolve interference
and is not a harmful-overlap transition.

The classifier separately reports half-duplex blocking, cochannel,
adjacent-channel, cross-technology, multiple-sufficient, joint-interference,
noise/propagation, and missing/incomplete-evidence cases. Allocation overlap
without the PHY counterfactual is not a hidden-terminal event.
The current hidden-terminal flag is deliberately conservative: it requires
at least one individually sufficient allocator-induced interferer. A jointly
sufficient harmful subset with no individually sufficient member remains a
`joint_interference` event rather than being promoted to hidden terminal.
The hidden flag may overlap the mutually exclusive assigned mode (for
example, `multiple_sufficient_interferers`), so `CompositionRate` is a
mode-specific prevalence among errors and the reported rates are not
required to sum to one.

Each run writes `failure_mode_events.csv`, `failure_mode_evidence.csv`, and
`failure_mode_summary.csv`. The seed-level result includes evidence coverage
and exhaustiveness rates, detected and analyzable mode counts, composition
rates over all terminal errors, incidence rates over correct-plus-error radio
fates, and status-effect-active endpoint hidden-terminal counts. Compare
treatments using rates with the same declared denominator; raw detected
counts alone also reflect changes in traffic opportunity volume.
The joined evidence file is deliberately sparse: it retains individually
sufficient or harmful-candidate rows, while the numbered raw counterfactual
chunks remain authoritative for joint mechanisms. Failure events still cover
every terminal error. The event and summary outputs explicitly distinguish a
valid header-only allocator-candidate artifact from unavailable legacy
allocator evidence; the latter cannot yield a complete hidden-terminal
classification.

An exposed terminal starts with a `missed_reuse` pair whose live endpoints
are in separate time slots and whose oracle endpoints are cochannel. An
exact-resource `missed_reuse` pair that is already concurrent on different
frequencies is not an exposed-terminal opportunity. A temporal candidate
becomes an exposed opportunity only when a complete shadow evaluation
predicts that every relevant same-technology receiver remains above the
configured PRR safety threshold after the reuse.
Incomplete prediction sets remain explicitly unclassified.

The campaign writes a sampled `exposed_reuse_shadow_manifest.csv` in every
run. `MaximumExposedShadowCases`,
`ExposedShadowEvaluationHorizonSeconds`, and
`MinimumShadowReceiverObservationCount` predeclare the replay workload and
coverage rule. Sampling probabilities and inverse-probability weights are
retained when the case limit subsamples missed-reuse events. The current
legacy simulation loop does not yet execute full-state forks, so nonempty
manifests have classification status `ShadowRunRequired` and
`ExposedTerminalCount` remains unavailable. They must be processed by the
strict shadow reducer described in
`docs/exposed-reuse-shadow-evaluation.md`; pending cases must never be
interpreted as zero exposed terminals.

The Ramp policy fixes the horizon to the 0.1-second allocation interval and
ends before the next decision. The observation requirement is met by
independent paired replications from the same checkpoint, not by locking the
initial oracle resource across later controller epochs.

## PRR-AUC

The reducer builds a fixed distance grid, retains empty bins, inserts the
explicit point `(0 m, 1)`, applies trapezoidal integration through the
configured maximum distance, and divides by that distance. Empty scored bins
make the AUC incomplete; changing the integration domain from run to run
would otherwise create a false treatment effect.

Route-matched effects are formed within each paired seed:

\[
\Delta_G = \frac{1}{2}
  \left[(G_M-B_M) + (G_R-B_R)\right],
\quad
\Delta_{FE}=FE-B_M,
\quad
\Delta_{FM}=FM-B_R.
\]

Here \(M\) and \(R\) denote mainline and ramp transmitter populations.

## Structure-versus-magnitude conclusion

The final model is fitted to paired baseline deltas:

```text
delta response ~ seed block + error model * categorical magnitude
```

Overlapping drop-block partial R-squared is reported for:

- error structure: model main effects plus model-by-magnitude interaction;
- magnitude: categorical magnitude main effects plus
  model-by-magnitude interaction.

The interaction is present in both removed blocks, so these two partial
R-squared values are nonadditive operational predictive-contribution
statistics, not shares of a variance decomposition. Their comparison is
conditional on the configured factor levels and degrees of freedom.

A separate predictive sensitivity uses leave-one-seed-out mean squared
error on seed-centered treatment deltas. It fits four models: intercept only
(`N`), structure only (`S`), magnitude only (`M`), and the full factorial
(`SM`). Two-factor Shapley loss reduction averages the two factor-entry
orders, so the interaction improvement is allocated exactly once rather than
credited to both factors. The analysis stores all four losses, per-seed
losses, normalized structure and magnitude contributions, a seed-block
bootstrap interval for their difference, and a distinct
`PredictiveSensitivityConclusion`. Report this alongside the overlapping
partial-R-squared conclusion; disagreement is a robustness warning rather
than a reason to select whichever statistic gives the preferred answer.

Magnitude is categorical by default because three or more tested levels can
have a nonlinear response; forcing a single slope can understate magnitude's
contribution. `MagnitudeModel="continuous"` is the predeclared linear
sensitivity analysis, not the primary result. The chosen model is stored in
the campaign manifest and every analysis result.

Complete seed blocks are bootstrapped. The conclusion is
`ErrorStructureDominates` only when the 95% interval for
`partialR2(structure) - partialR2(magnitude)` is entirely above zero;
`MagnitudeDominates` requires it to be entirely below zero. Otherwise the
result is `Inconclusive`.

Apply that rule first to the mainline and ramp analyses. Agreement across
routes supports a general structure claim; disagreement is a
route-by-structure result, not evidence that either route should be pooled
away. The combined three-model result is a predeclared equal-route-weight
description and is labeled as such in its analysis JSON.

This conclusion is conditional on the tested scenario, magnitude range,
within-route estimand, controller, radio settings, and seed population. It
should be accompanied by the mechanism metrics, realized-magnitude
sensitivity, and manipulation checks, not reported as a PRR-AUC comparison
alone.

## Important secondary analyses

The primary factorial intentionally treats temporal persistence and
directionality as parts of error structure. To determine *which* structural
property matters, add pre-registered secondary arms that independently vary:

- persistence: hold a Gaussian draw for a matched status-effect duration;
- anisotropy/direction: constrain Gaussian displacement to the false-route
  direction;
- exposure duration: match active vehicle-time, not just selected fraction;
- reset policy and boundary censoring;
- magnitude distribution or 95th percentile instead of the mean.

Use seed-block confidence intervals for campaign effects. For vehicle-level
or episode-level summaries, cluster resampling by seed first and vehicle
within seed; packet links and time samples from one vehicle are not
independent replicates.
