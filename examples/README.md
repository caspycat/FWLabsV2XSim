# FWLabsV2XSim v7 examples

These examples form a short, progressive introduction to the public V7
configuration, execution, and output contracts. Use the simulator through a
MATLAB Project environment:

- in a research project, add the FWLabsV2XSim submodule folder as a referenced
  project; or
- when contributing to the simulator, open `FWLabsV2XSim.prj` directly.

The project environment puts the simulator and its dependencies on the MATLAB
path. The `examples` folder is intentionally not on that path.

| Lesson folder | Script | Main idea |
|---|---|---|
| `01_run_first_simulation` | `run_first_simulation.m` | Load and resolve a namespaced TOML configuration, run NR-V2X Mode 2, and read `simulation_summary.json`. |
| `02_reproduce_traffic` | `reproduce_traffic.m` | Keep traffic fixed with a scenario-owned seed while changing radio and allocator seeds through nested patches. |
| `03_compare_named_allocators` | `compare_named_allocators.m` | Select each cellular-sidelink resource allocator by name and inspect its metadata. |
| `04_apply_position_errors` | `apply_position_errors.m` | Compose Gaussian, false-route, and delay errors on an exit-ramp scenario. |
| `05_inspect_output_artifacts` | `inspect_output_artifacts.m` | Enable hook-backed JSON and CSV outputs and read them in MATLAB. |
| `06_run_density_sweep` | `run_density_sweep.m` | Give every campaign case its own run directory and aggregate completion summaries. |
| `07_run_nr_mode1` | `run_nr_mode1.m` | Run NR-V2X with a centralized allocator and inspect Mode 1 metadata and PRR. |
| `08_run_nr_mode1_etsi_campaign` | `run_nr_mode1_etsi_campaign.m` | Sweep the three 3GPP freeway traffic presets with paired Mode 1 seeds. |
| `09_explore_traffic_scenarios` | `explore_traffic_scenarios.m` | Run and plot all five public mobility scenarios under one NR Mode 1 baseline. |
| `10_run_nr_mode2` | `run_nr_mode2.m` | Run NR-V2X Mode 2 with every sensing/SPS option and inspect the derived beacon-resource grid. |
| `11_compare_lte_modes` | `compare_lte_modes.m` | Compare centralized LTE-V2X Mode 3 with autonomous Mode 4. |
| `12_compare_ieee80211p` | `compare_ieee80211p.m` | Compare native/surrogate IEEE PHYs and static/adaptive repetition. |
| `13_compare_coexistence_methods` | `compare_coexistence_methods.m` | Run Standard and coexistence Methods A/B/C/F under one paired baseline. |
| `14_compare_channel_models` | `compare_channel_models.m` | Compare path loss, threshold/curve decoding, and fading. |
| `15_compare_application_traffic` | `compare_application_traffic.m` | Compare periodic traffic with discretized ETSI-CAM and congestion control. |
| `16_run_roadside_unit` | `run_roadside_unit.m` | Run a fixed IEEE DENM roadside unit and filter directed packet fates. |
| `17_reduce_packet_fates` | `reduce_packet_fates.m` | Reduce packet-fate chunks using the public table-oriented analysis API. |

For example, from the simulator repository root:

```matlab
run(fullfile("examples","01_run_first_simulation","run_first_simulation.m"))
```

From a research project whose submodule is stored below
`dependencies/FWLabsV2XSim`, stay in the research project root and run:

```matlab
researchProject = currentProject;
simulatorRoot = fullfile( ...
    researchProject.RootFolder,"dependencies","FWLabsV2XSim");
run(fullfile(simulatorRoot,"examples","01_run_first_simulation","run_first_simulation.m"))
```

Adjust only the submodule location. Do not add `examples` to the MATLAB path.
Each script locates its companion files from `mfilename("fullpath")`, so its
behavior is independent of the current working directory.

Every tutorial directly demonstrates the public invocation sequence:

```matlab
template = v2xsim.config.load(configurationFile);
configuration = template.resolve();
simulationResult = v2xsim.runSimulation( ...
    configuration, ...
    OutputDirectory=outputDirectory, ...
    RunLabel="example-run");
```

The scripts capture the returned `v2xsim.runtime.SimulationResult` and leave
`exampleResults` and `exampleOutputDirectory` in the caller workspace. Any
supporting MATLAB functions are local to the tutorial file; no tutorial
depends on another example `.m` file.

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
The distance-binned delivery-PRR figures repeat each experiment five times
with distinct seeds and pool the packet-fate counts before calculating the
curve. They show
the explicit synthetic `(0 m, 1)` anchor, and mark the paper-standard first
downward 90%-PRR crossing. A right-censored label means the curve remains
above 90% through its last measured bin; it is not evidence of a longer
range. An incomplete-distance-grid label means the short tutorial run did not
observe every configured bin, so no PRR range is reported.

The examples use deliberately small simulations. They demonstrate APIs and
data flow, not statistically supported trends or publication conclusions.
Runtime depends on the computer. A script that takes more than 30 seconds
emits the advisory warning `v2xsimexample:SlowExample` but still completes
normally and returns its results.

The packet-fate lesson selects CSV rather than Parquet, so the examples add no
toolbox requirement beyond the simulator's documented dependencies.

## Further reading

- [V7 TOML configuration](../docs/toml-configuration-v7.md)
- [BR resource allocation](../docs/br-resource-allocation.md)
- [Simulation outputs](../docs/simulation-output-v7.md)
- [Correctness and integration testing](../docs/testing-v7.md)
