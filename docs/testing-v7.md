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
if any test is unsuccessful. To keep a report at a chosen location:

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

Publication regressions are excluded by default. They can be included
explicitly with `IncludeRegressionTests=true`, but that includes every
discovered regression, including long-running campaigns. Shortened publication
campaigns should continue to be selected and reported separately; they do not
prove a full-duration publication conclusion.

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

## Parallel execution

Independent density points, seeds, and campaign configurations may be
distributed across local **process** workers. Thread workers are not supported
while the legacy simulator mutates process-wide state. Each work item must have
an exclusive output directory and component-owned seed, and runners must
restore the MATLAB path, current folder, warning state, explicitly declared
environment variables, and global random stream even when a work item fails.
