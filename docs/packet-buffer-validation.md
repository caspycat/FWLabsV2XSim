# Packet-buffer implementation validation

Validation environment: MATLAB R2026a on Windows, 9 September 2026.
Configuration and semantics are documented in the
[TOML reference](toml-configuration-v7.md) and
[output reference](simulation-output-v7.md).

## Checks

- The affected ordinary suite passed **416/416 tests**, with no failures or
  incomplete tests. It covers `runtime`, `legacy`, `hooks`, `hook`,
  `resource`, `packet`, `config`, and `integration` under `tests/+v2xsimtest`.
  It includes queue conservation, capacity validation, on-air protection,
  retransmissions, lifecycle retirement, initial backoff for queued packets,
  timestamp preservation, histogram growth, and output reconciliation.
- All four dedicated saturated-repetition cases passed: IEEE 802.11p, LTE,
  NR, and coexistence. Each reconciles packet-fate, PRR, and summary counts.
- `checkcode(file, "-id")` on all 32 changed MATLAB files: zero diagnostics.
- `git diff --check`: no whitespace errors.

The final ordinary-suite result is recorded in `v2x-buffer-complete-suite.log`
under MATLAB's `tempdir`; serialized results are in
`v2x-buffer-complete-results.mat` in the same directory.

## Scientific and numerical checks

All four checks in `Zhuofei2023RepetitionTest` and
`CoexistenceModeBehaviorTest` passed after the terminal-count correction.
The repetition campaigns use five simulated seconds per case; the coexistence
comparison uses three seconds and seeds 10–12. Campaigns used all 12 workers
exposed by the selected local Processes profile, without an imposed worker cap.

Four additional fixed-seed, six-UE, 0.6-second capacity-1 comparisons produced
exactly equal `simulation_summary.json` `Results` against original engine
functions extracted from Git HEAD into an isolated temporary directory. The
comparison asserted that current and reference engine functions resolved to
different directories. These representative runs cover all four radio modes.

The saturated coexistence/repetition test exposed two provisional IEEE 802.11p
errors that had no terminal packet-fate records. Summary counters now commit
first-success and final-error events, including errors on eviction of an
attempted packet. A focused regression also verifies stable UE-row indexing
with reordered active vehicles. Summaries with unfinished repetitions can
deliberately differ from historical results; no pending packet receives an
invented terminal error at simulation end.

## Storage and operation measurements

An isolated FIFO microbenchmark measured the retained packet-record array and
1,000 overflow admissions after filling each queue:

| Capacity | Record-array bytes | Seconds for 1,000 admissions |
| ---: | ---: | ---: |
| 1 | 585 | 0.066 |
| 64 | 30,825 | 0.074 |
| 4,096 | 1,966,185 | 0.309 |

These are observations, not runtime guarantees or full-simulator benchmarks.
Storage follows actual occupancy; struct-array removal has a copying cost
that increases with queue length. No toolbox dependency was added.

## Limits

The full repository correctness/coverage gate and full-duration or exhaustive
publication campaigns were not run. Shortened regressions and representative
numerical parity do not establish full-duration publication conclusions.
Larger capacities intentionally change loss, delay, and peak data age; their
scientific usefulness must be assessed for the intended traffic workload.
