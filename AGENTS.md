# FWLabsV2XSim Agent Guide

## Engineering priorities

When requirements compete, use this order:

1. Robustness and correctness.
2. Modern software design, maintainability, and extensibility.
3. Runtime and resource efficiency.

This repository targets MATLAB R2026a. Follow current MathWorks
recommendations and use modern MATLAB features deliberately. Avoid deprecated
functions and legacy patterns.

Prefer MATLAB built-ins to custom implementations. If an official MathWorks
toolbox meaningfully replaces home-grown infrastructure or algorithms, use it.
Introducing a toolbox dependency requires a clear justification, updated
dependency documentation, and a useful diagnostic when the toolbox is
unavailable. Do not install toolboxes or other dependencies unless explicitly
requested. A custom implementation is justified when the built-in or toolbox
implementation has a significant performance cost for the way this simulator
uses it; measure that cost when the tradeoff is material.

Prefer modern data structures, including tables and dictionaries, when they
match the data model. Prefer string scalars and string arrays to character
vectors and cell arrays of character vectors. Use typed `arguments` blocks,
validators, package-qualified names, and stable namespaced error identifiers.

Vectorize simulation-scale computations where practical, while preserving
correctness and readability. Keep functions pure where practical: pass state
through explicit inputs and outputs, isolate side effects at clear boundaries,
and avoid hidden dependencies on global variables, paths, environment
variables, warnings, or the global random stream.

Use line continuation marks (`...`) conservatively. Prefer naturally readable
expressions, well-named local variables, or small focused helpers to
unnecessarily fragmented statements.

Liberally add comments to code. When implementing technical standards or referencing papers,
provide document reference numbers.

## Architecture and compatibility

- Put modern production code in `src/+v2xsim`.
- Put unit and smoke tests in `tests/+v2xsimtest`.
- Put publication-oriented regressions in
  `regression-tests/+v2xsimregression`.
- Treat `old_src` as a behavioral and scientific reference, not an
  architecture or API that v7 must preserve.
- Put public documentation in `docs` and the relevant workflow README files.

V7 is effectively a rewrite. Preserve feature parity and scientifically
meaningful behavior, not v6 API compatibility. Do not preserve v6 function
signatures, parameter names, internal structures, globals, or control flow
merely for compatibility. Do not add v6 adapters, aliases, or new v6-style
interfaces unless the task explicitly requires them. Use dotted v7 parameter
names and native v7 abstractions in all new or migrated workflows.

Published workflows are also implementation code and may be updated to use the
v7 API. Preserve their experimental intent, parameter meaning, reproducible
setup, and publication-level conclusions rather than historical calling syntax,
intermediate state, or byte-for-byte output. Update campaign runners,
configurations, plotting inputs, and regression fixtures as needed. Document
deliberate differences among publication prose, archived executable
configuration, and the v7 representation. Prefer conclusion-level regression
contracts to comparisons against plot pixels or individual Monte Carlo samples.

## Correctness and testing

Design for testability. Keep numerical and transformation logic pure, and
separate it from filesystem access, plotting, environment mutation, and
simulation orchestration. Use explicit, component-owned random streams and
seeds. Tests and campaign helpers must restore every global state they change,
including the MATLAB path, global random stream, warnings, and environment
variables.

Be aggressive when adding tests. For every changed behavior, consider:

- ordinary, boundary, degenerate, and extreme valid inputs;
- empty and singleton values;
- incompatible dimensions, table schemas, and types;
- nonfinite or otherwise invalid values;
- state transitions, repeated calls, and ordering effects;
- interactions with related components;
- numerical precision and deterministic randomness;
- failure, warning, and cleanup paths;
- independence from global state and test execution order.

Use precise behavioral assertions. Verify warning and error identifiers where
they form part of the diagnostic contract. Every defect fix must include a
regression test that fails without the fix. Keep tests deterministic, isolated,
and independent of execution order.

Validation is tiered:

1. Run focused `matlab.unittest` tests for affected behavior.
2. Run `checkcode(file, "-id")` on every changed MATLAB file.
3. Run broader unit suites when shared abstractions or public contracts change.
4. Run shortened paper regressions when scientific workflows may be affected.
5. Run full-duration publication campaigns only when explicitly requested or
   when a change may alter a published conclusion.

Report exactly which checks ran, their results, and any relevant checks that
were omitted. Do not imply that a shortened campaign proves a full-duration
scientific conclusion.

## Repository safety and completion

Inspect the worktree before editing and preserve unrelated user changes. Never
discard or overwrite work that is outside the task. Write generated simulation
output to temporary directories by default; do not overwrite user research
artifacts or use checked-in output as scratch space.

Do not commit, push, rewrite Git history, or install dependencies unless
explicitly requested.

Update documentation in the same task whenever public behavior, parameters,
output formats, toolbox requirements, feature coverage, or reproduction
workflows change.

At completion, report:

- the behavior implemented and the important design decisions;
- feature-parity or scientific-workflow implications;
- any new toolbox dependency;
- the tests and analysis performed, including omitted relevant checks;
- remaining correctness, numerical, scientific, or performance risks.
