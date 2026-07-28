# Simulation output

Each `WiLabV2Xsim` invocation exclusively owns one run directory. The
`output.Directory` value must name either a nonexistent directory or an
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

## Completion summary

`simulation_summary.json` is written last. Its presence is the completed-run
signal; partial runs do not have a summary. The file is first serialized to a
temporary file in the same directory and then renamed into place. It is strict
JSON: nonfinite MATLAB values are represented as JSON `null`, while state
fields explain why a value is unavailable.

The versioned root has three sections:

```text
SchemaVersion
Run
Configuration
Results
```

`Run` records simulator provenance, the simulation random seed, durations,
the configuration file, and the user-supplied run label. `Configuration`
contains typed nested objects
for scenario, infrastructure, positioning, packet generation, resource pool,
radio channels, cellular sidelink, IEEE 802.11p, propagation, coexistence,
resource allocation, and awareness ranges.

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
