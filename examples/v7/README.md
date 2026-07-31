# FWLabsV2XSim v7 examples

These examples form a short, progressive introduction to the public V7
configuration and output contracts. Open `FWLabsV2XSim.prj`, then run the
MATLAB scripts in numerical order:

| Lesson | Script | Main idea |
|---|---|---|
| 1 | `v7_01_run_first_simulation.m` | Load and resolve a namespaced TOML configuration, run NR-V2X Mode 2, and read `simulation_summary.json`. |
| 2 | `v7_02_reproduce_traffic.m` | Keep traffic fixed with a scenario-owned seed while changing radio and allocator seeds through nested patches. |
| 3 | `v7_03_compare_named_allocators.m` | Select each cellular-sidelink resource allocator by name and inspect its metadata. |
| 4 | `v7_04_apply_position_errors.m` | Compose Gaussian, false-route, and delay errors on an exit-ramp scenario. |
| 5 | `v7_05_inspect_output_artifacts.m` | Enable hook-backed JSON and CSV outputs and read them in MATLAB. |
| 6 | `v7_06_run_density_sweep.m` | Give every campaign case its own run directory and aggregate completion summaries. |
| 7 | `v7_07_run_nr_mode1.m` | Run NR-V2X with a centralized allocator and inspect Mode 1 metadata and PRR. |
| 8 | `v7_08_run_nr_mode1_etsi_campaign.m` | Sweep the three 3GPP freeway traffic presets with paired Mode 1 seeds. |
| 9 | `v7_09_explore_traffic_scenarios.m` | Run and plot all four public mobility scenarios under one NR Mode 1 baseline. |
| 10 | `v7_10_run_nr_mode2.m` | Run NR-V2X Mode 2 with every sensing/SPS option and inspect the derived beacon-resource grid. |
| 11 | `v7_11_compare_lte_modes.m` | Compare centralized LTE-V2X Mode 3 with autonomous Mode 4. |
| 12 | `v7_12_compare_ieee80211p.m` | Compare native/surrogate IEEE PHYs and static/adaptive repetition. |
| 13 | `v7_13_compare_coexistence_methods.m` | Run Standard and coexistence Methods A/B/C/F under one paired baseline. |
| 14 | `v7_14_compare_channel_models.m` | Compare path loss, threshold/curve decoding, and fading. |
| 15 | `v7_15_compare_application_traffic.m` | Compare periodic traffic with discretized ETSI-CAM and congestion control. |
| 16 | `v7_16_run_roadside_unit.m` | Run a fixed IEEE DENM roadside unit and filter directed packet fates. |
| 17 | `v7_17_reduce_packet_fates.m` | Reduce packet-fate chunks using the public table-oriented analysis API. |

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

Every file under `config/` is TOML 1.0 and uses the exact-case V7 namespace.
MATLAB code loads a reusable template, supplies an optional sparse nested
struct through `v2xsim.config.patch`, and resolves one immutable
`v2xsim.config.ResolvedConfiguration`. Dotted name-value overrides and legacy
`.cfg` files are not part of the V7 API.

Run identity is deliberately outside the scientific configuration:
`OutputDirectory` and `RunLabel` are typed options of
`v2xsim.runSimulation`. Every simulator invocation receives a new exclusive
output directory. The simulator never clears, resumes, or appends to an
existing nonempty run directory. Multi-run examples therefore create one
child directory per case.

The files are retained after the script finishes so they can be inspected.

The examples use deliberately small simulations. They demonstrate APIs and
data flow, not statistically supported trends or publication conclusions.
Runtime depends on the computer. A script that takes more than 30 seconds
emits the advisory warning `v2xsimexample:SlowExample` but still completes
normally and returns its results.

The packet-fate lesson selects CSV rather than Parquet, so the examples add no
toolbox requirement beyond the simulator's documented dependencies.

## Further reading

- [V7 TOML configuration](../../docs/toml-configuration-v7.md)
- [BR resource allocation](../../docs/br-resource-allocation.md)
- [Simulation outputs](../../docs/simulation-output-v7.md)
- [Correctness and integration testing](../../docs/testing-v7.md)
