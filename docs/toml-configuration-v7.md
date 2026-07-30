# TOML configuration in V7

FWLabsV2XSim V7 reads only TOML 1.0 configuration files. The schema is
case-sensitive, begins with `SchemaVersion = 1`, and uses nested tables rather
than dotted command-line parameter names. Legacy `.cfg` files, V6 aliases,
configuration-file fallbacks, and dotted name-value overrides are not
supported.

Configuration and execution metadata are separate:

```matlab
template = v2xsim.config.load("experiment.toml");
patch = v2xsim.config.patch(struct( ...
    Simulation=struct(DurationSeconds=30, RandomSeed=17), ...
    Scenario=struct( ...
        BidirectionalHighway=struct(VehicleCount=200))));
configuration = template.resolve(Patch=patch);

result = v2xsim.runSimulation( ...
    configuration, ...
    OutputDirectory="results/seed-17", ...
    RunLabel="density-200/seed-17");
```

`OutputDirectory` and `RunLabel` are run options. They are deliberately absent
from the scientific configuration, so one resolved configuration can be reused
for multiple isolated runs.

## Configuration lifecycle

`v2xsim.config.load` parses one `.toml` file into a
`v2xsim.config.ConfigurationTemplate`. A template contains only authored
values and their provenance; defaults are not applied while it is reusable.
Relative packet-error curve directories are converted to absolute paths
relative to the TOML file, so worker behavior does not depend on its current
directory.

`v2xsim.config.patch` accepts one sparse, nested scalar struct. Its field names
and casing must match the TOML schema exactly. Tables merge recursively.
Scalars, numeric or string arrays, and arrays of tables replace the previous
value atomically.

`ConfigurationTemplate.resolve` applies a patch, selects tagged branches,
fills defaults, validates cross-field constraints, and returns an immutable
`v2xsim.config.ResolvedConfiguration`. The resolved object exposes:

- `Data`: the complete effective value tree for the selected variants;
- `Provenance`: a `Path`/`Source` table for every effective leaf;
- `sourceFor(path)`: the source of one resolved leaf.

Provenance sources are `Default`, `Derived`, `Template`, `Patch`, or
`File:<path>`. Array-of-table leaves use indexed paths such as
`Positioning.Errors(1).SelectionRandomSeed`, so authored, defaulted, and
derived values within one entry remain distinguishable. Resolution is pure:
it does not change the current directory, MATLAB path, warning state, or global
random stream.

## TOML example

```toml
SchemaVersion = 1

[Simulation]
RandomSeed = 17
DurationSeconds = 10

[Scenario]
Type = "BidirectionalHighway"
UpdateIntervalSeconds = 0.1

[Scenario.BidirectionalHighway]
RandomSeed = 101
VehicleCount = 80
NLanes = 3
LaneWidth = 4
RoadLength = 2000
CentralDividerWidth = 0
MeanVehicleSpeed = 33.3333333333333
VehicleSpeedStandardDeviation = 3.33333333333333
RerollSpeedOnWrapAround = false

[Application]
PacketSizeBytes = 300
ResourceReservationIntervalSeconds = 0.1

[Application.PacketGeneration]
Mode = "Periodic"
IntervalSeconds = 0.1
IntervalVariationSeconds = 0
RandomComponentMeanSeconds = 0

[Radio]
Type = "NrV2X"
BandwidthMHz = 10
TransmitPowerDbm = 23
FixedPowerDensityEnabled = false
ReceiverNoiseFigureDb = 6

[Radio.NrV2X]
SubcarrierSpacingKilohertz = 30
DmrsResourceElementCountPerSlot = 18
Mcs = 8
SciSymbolCount = 3
SciResourceBlockCount = 12

[Radio.Sidelink.ResourcePool]
SubchannelSizeResourceBlocks = 12
PartialFrequencyOverlapEnabled = true

[Channel.PathLoss]
Model = "WinnerPlusB1"

[Awareness]
RangesMeters = [100, 300]

[ResourceAllocation]
Type = "SensingBased"
RandomSeed = 201

[ResourceAllocation.SensingBased]
KeepResourceProbability = 0.5

[Outputs.PacketReceptionRatio]
Enabled = true
DistanceBinWidthMeters = 10
```

Files may be sparse. Omitted values receive schema defaults during resolution,
and the resolved `Data` tree records those effective values.

## Tagged variants

Tagged tables prevent unrelated options from coexisting silently. Every
discriminator and branch name is case-sensitive.

### Scenario

`Scenario.Type` selects exactly one branch:

| Type | Selected table |
|---|---|
| `BrownianMotion` | `Scenario.BrownianMotion` |
| `BidirectionalHighway` | `Scenario.BidirectionalHighway` |
| `EtsiHighway` | `Scenario.EtsiHighway` |
| `ExitRampHighway` | `Scenario.ExitRampHighway` |

An authored table for a different scenario is an error. A patch that changes
`Type` atomically replaces the prior selected branch before defaults are
applied.

### Radio

`Radio.Type` is one of `Ieee80211p`, `LteV2X`, `NrV2X`, or `Coexistence`.
Single-technology configurations select the matching `Radio.<Type>` table.
`Radio.Sidelink` holds LTE/NR-shared settings.

For coexistence:

```toml
[Radio]
Type = "Coexistence"

[Radio.Coexistence]
SidelinkType = "LteV2X" # or "NrV2X"
InterferenceModel = "Independent" # or "Cochannel"

[Radio.LteV2X]
Mcs = 7

[Radio.Ieee80211p]
Mcs = 2
```

The coexistence branch permits only `Radio.Coexistence`,
`Radio.Ieee80211p`, the selected sidelink technology, and shared radio tables.

### Resource allocation

`ResourceAllocation.Type` selects one table:

| Type | Purpose |
|---|---|
| `ReuseDistance` | Controlled minimum-distance reuse |
| `MaximumReuseDistance` | Controlled maximum-distance assignment |
| `MinimumReusePower` | Controlled minimum-received-power assignment |
| `SensingBased` | 3GPP autonomous sensing and semi-persistent scheduling |
| `Random` | Random benchmark |
| `Ordered` | Position-ordered benchmark |

`RandomSeed` and `FullDuplex` are common fields. Options in an inactive
allocator table are rejected.

### Packet generation

`Application.PacketGeneration.Mode` is `Periodic` or `EtsiCam`. The
`Application.PacketGeneration.Cam` table is active only for `EtsiCam`;
authoring it for periodic generation is an error.

### Coexistence method

`Coexistence.Method` is `Standard`, `MethodA`, `MethodB`, `MethodC`, or
`MethodF`. A non-standard value activates only its matching table. With
`Radio.Coexistence.InterferenceModel = "Independent"`, only
`Coexistence.VehiclePattern` is active because coexistence mitigation and
shared-channel measurements are not used.

## Ordered arrays of tables

Positioning errors are applied in authored order:

```toml
[[Positioning.Errors]]
Type = "Gaussian"
StandardDeviationMeters = 3
DisplacementRandomSeed = 304
AffectedVehicleProbability = 1
SelectionRandomSeed = 404
ResetAfterSeconds = inf
ActiveRoutes = ["Merge", "Adjacent"]

[[Positioning.Errors]]
Type = "Delay"
DelaySeconds = 0.1
```

Supported error types are `Gaussian`, `Delay`, `FalseExit`, and `FalseMerge`.
A patch replaces the complete `Positioning.Errors` array; entries are not
merged by index.

`Gaussian.ActiveRoutes` is either `["All"]` or a nonempty, duplicate-free
array drawn from `"Ramp"`, `"Merge"`, and `"Adjacent"`.

Roadside units use the same TOML construct:

```toml
[[Infrastructure.RoadsideUnits]]
Id = "rsu-west"
Technology = "Ieee80211p"
PacketType = "Denm"
PositionMeters = [250, 8]
```

Identifiers must be nonblank, unique, and outside the generated `V1`, `V2`,
... vehicle namespace. A single run currently requires homogeneous roadside
unit technology and packet type. Single-technology radio configurations
accept only their active technology (`LteV2X` also represents the cellular
side of an NR-V2X run); coexistence accepts either technology.

## Namespace guide

| Namespace | Contents |
|---|---|
| `Simulation` | Master seed and simulation duration |
| `Scenario` | Mobility variant, update interval, and selected scenario options |
| `Application` | Packet size, reservation interval, packet generation, channel-load measurement, and congestion control |
| `Radio` | Radio variant, common link settings, IEEE 802.11p, LTE-V2X, NR-V2X, sidelink, and resource-pool settings |
| `Channel` | Packet-error model, path loss, fading, fixed obstacle constants, and shadowing |
| `Awareness` | Positive distance ranges used by awareness metrics |
| `ResourceAllocation` | Tagged allocator and its algorithm-specific settings |
| `Coexistence` | Technology population, superframe, mitigation method, and coexistence channel-load settings |
| `Positioning` | Ordered positioning-error array |
| `Infrastructure` | Roadside-unit array |
| `Outputs` | Optional recorder configuration |

Optional output recorders are disabled by default. Recorder tables include
`AverageNeighborCount`, `VehicleKinematics`, `PositionErrorTrace`,
`ControllerDiagnostics`, `PacketFateTrace`, `InterferenceClassification`,
`UpdateDelay`, `WirelessBlindSpot`, `PacketDelay`, `DataAge`,
`PacketReceptionRatio`, `ChannelBusyRatio`, and
`CoexistenceTechnologyShare`.

## Validation rules

Loading performs TOML syntax, schema-version, key, and authored-value
validation. Resolution selects variants, applies defaults, and then checks
completeness and cross-field constraints. Together these stages reject:

- an extension other than `.toml`;
- a missing or unsupported `SchemaVersion`;
- unknown or incorrectly cased keys;
- values of the wrong TOML or MATLAB type;
- inactive tagged branches;
- invalid enum values, bounds, array lengths, or cross-field combinations;
- legacy automatic-threshold sentinel `-1000`, seed `0`, and textual
  `"null"` sentinels.

Omission represents “use the default” or “automatic”. TOML has no null value
in this schema. Positive infinity is accepted only for documented unbounded
durations or limits, such as `ResetAfterSeconds` and
`MaximumConsecutiveReservationIntervals`; nonfinite values elsewhere are
rejected.

The master seed defaults to the fixed value `1`. Component-owned seeds are
either authored explicitly or derived deterministically during resolution.
Resolution never chooses a seed from wall-clock time and never consumes the
global random stream.

LOS packet-decoding thresholds have one canonical home:
`Channel.PacketError.Ieee80211pLosThresholdDb` and
`Channel.PacketError.SidelinkLosThresholdDb`. IEEE 802.11p repetition
`CbrThresholds` contains exactly three values.

For `Channel.PacketError.Model = "Curves"`, `CurveDirectory` is required.
Relative directories in TOML are resolved against the configuration file.
Programmatic patches must provide absolute curve-directory paths. Custom
`Channel.Obstacles` attenuation is rejected: the fixed values describe the
established non-map runtime, while map-backed trace scenarios are outside the
current V7 feature set.

## Migrating a campaign

Build patch data as ordinary nested values so it is serializable across
process workers:

```matlab
patchData = struct( ...
    Simulation=struct(RandomSeed=seed), ...
    Scenario=struct( ...
        BidirectionalHighway=struct(VehicleCount=vehicleCount)), ...
    ResourceAllocation=struct(RandomSeed=seed));

configuration = template.resolve( ...
    Patch=v2xsim.config.patch(patchData));
result = v2xsim.runSimulation( ...
    configuration, ...
    OutputDirectory=runDirectory, ...
    RunLabel=label);
```

Do not concatenate dotted name-value cells, encode “automatic” with a magic
number, or place output paths in TOML.
