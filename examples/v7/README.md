# FWLabsV2XSim v7 examples

These examples form a short, progressive introduction to the public V7
configuration and output contracts. Open `FWLabsV2XSim.prj`, then run the
MATLAB scripts in numerical order:

| Lesson | Script | Main idea |
|---|---|---|
| 1 | `v7_01_run_first_simulation.m` | Run NR-V2X from a dotted-name configuration and read `simulation_summary.json`. |
| 2 | `v7_02_reproduce_traffic.m` | Keep traffic fixed with `scenarioOptions.RandomSeed` while changing radio and allocator seeds. |
| 3 | `v7_03_compare_named_allocators.m` | Select each cellular-sidelink resource allocator by name and inspect its metadata. |
| 4 | `v7_04_apply_position_errors.m` | Compose Gaussian, false-route, and delay errors on an exit-ramp scenario. |
| 5 | `v7_05_inspect_output_artifacts.m` | Enable hook-backed JSON and CSV outputs and read them in MATLAB. |
| 6 | `v7_06_run_density_sweep.m` | Give every campaign case its own run directory and aggregate completion summaries. |

For example, from the repository root:

```matlab
run("examples/v7/v7_01_run_first_simulation.m")
```

Each script locates the repository independently of the current working
directory. It leaves `exampleResults` and `exampleOutputDirectory` in the
caller workspace, prints the output path, and restores the MATLAB path,
warning configuration, and global random stream after every simulator
invocation.

## Configuration and output rules

Every file under `config/` uses canonical dotted V7 parameter names. A script
may add name-value arguments to override its configuration baseline; those
arguments have higher precedence than the file.

Every simulator invocation receives a new temporary output directory.
`v2xsim.runSimulation` never clears, resumes, or appends to an existing nonempty run
directory. Multi-run examples therefore create one child directory per case.
The files are retained after the script finishes so they can be inspected.

The examples use deliberately small simulations. They demonstrate APIs and
data flow, not statistically supported trends or publication conclusions.
Runtime depends on the computer. A script that takes more than 30 seconds
emits the advisory warning `v2xsimexample:SlowExample` but still completes
normally and returns its results.

The packet-fate lesson selects CSV rather than Parquet, so the examples add no
toolbox requirement beyond the simulator's documented dependencies.

## Further reading

- [V7 simulator parameters](../../docs/simulator-parameters-v7.md)
- [BR resource allocation](../../docs/br-resource-allocation.md)
- [Simulation outputs](../../docs/simulation-output-v7.md)
- [Correctness and integration testing](../../docs/testing-v7.md)
