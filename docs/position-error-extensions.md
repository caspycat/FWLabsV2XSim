# Custom position-error modules

Research projects can add controller-visible positioning errors without
modifying FWLabsV2XSim. A custom module subclasses
`v2xsim.positioning.PositionErrorModule`; the research project constructs a
module instance and supplies it to one simulation through an explicit
`v2xsim.positioning.PositionErrorChainSpecification`.

The MATLAB Project containing the module must reference the FWLabsV2XSim
project so both packages are available without changing the MATLAB path.

## Module contract

Implement the protected `doApply` method:

```matlab
classdef DriftError < v2xsim.positioning.PositionErrorModule
    properties (SetAccess = immutable)
        OffsetMeters (1,1) double {mustBeReal,mustBeFinite}
    end

    methods
        function obj = DriftError(offsetMeters)
            obj.OffsetMeters = offsetMeters;
        end
    end

    methods (Access = protected)
        function [obj,positions] = doApply(obj,positions,context)
            positions.X = positions.X + obj.OffsetMeters;
        end
    end
end
```

`inputPositions` is a named `X`/`Y` table containing controller-visible
vehicle positions. `context` supplies simulation time, the unmodified scenario
positions, and any specialized scenario capabilities. The module must preserve
the complete set of vehicle row identities. Row order has no semantic meaning.

Modules have value semantics by default and must return their updated `obj`.
Handle subclasses are also supported. Each module instance is run-owned: create
a fresh instance and chain specification for every run. A stochastic module
must own its random stream and accept an explicit seed; it must not consume or
replace MATLAB's global random stream.

The base class generates displacement diagnostics automatically. Override its
protected diagnostic builder only when the model has additional lifecycle or
network-update facts that fit the normalized position-error diagnostic schema.
The built-in packet-loss and fixed-delay modules use
`NetworkUpdateOutcome`, `OutputSourceTimeSeconds`, and `OutputAgeSeconds` for
this purpose; custom network models should preserve the same source-time/age
relationship while using a stable, nonblank outcome vocabulary.

`PositionDelayError` selects the newest stored module-input snapshot at or
before `currentTime - DelaySeconds`, allowing a comparison tolerance of
`16 * eps(max(1,currentTime))` seconds for floating-point arithmetic. Thus a
0.2-second delay at time 0.3 selects the report at 0.1 instead of adding an
unintended report interval. Differences within that tolerance are treated as
the same boundary; earlier targets outside it retain sample-and-hold behavior.
The reported source timestamp remains the actual stored time and the age is
current time minus that timestamp. Warm-up holds, current-position fallback
for identities absent from the selected snapshot, and native history semantics
remain unchanged. Research-specific wrap/re-entry episode resets must be
implemented explicitly in the custom module.

## Compose a run

TOML continues to configure built-in errors. A configured entry refers to a
built-in by its unique `Positioning.Errors.Type`; a custom entry carries the
module instance and its provenance descriptor:

```matlab
configuration = v2xsim.config.load("experiment.toml").resolve();

drift = research.positioning.DriftError(4);
driftDescriptor = struct( ...
    Name="GNSS drift treatment", ...
    Version="1.2.0", ...
    SourceRevision="4b91dce", ...
    Parameters=struct(OffsetMeters=4,RandomSeed=731));

entries = [ ...
    v2xsim.positioning.PositionErrorChainEntry.configured("Gaussian"), ...
    v2xsim.positioning.PositionErrorChainEntry.custom( ...
        drift,driftDescriptor), ...
    v2xsim.positioning.PositionErrorChainEntry.configured("Delay")];
chain = v2xsim.positioning.PositionErrorChainSpecification(entries);

result = v2xsim.runSimulation( ...
    configuration, ...
    OutputDirectory="results/drift", ...
    PositionErrorChainSpecification=chain);
```

When a specification is supplied, it is the complete ordered chain. Every
built-in present in `Positioning.Errors` must be referenced exactly once;
custom entries may occur anywhere. Omitting the run option preserves the TOML
chain and its authored order. Custom class names are deliberately not loaded
from TOML.

The custom descriptor must be a scalar struct composed only of nested structs,
cells, finite real numeric arrays, logical arrays, nonmissing strings, and
character vectors. Include enough information to identify the model version,
source revision, parameters, and random seeds. FWLabsV2XSim records the
descriptor but does not infer or serialize arbitrary module properties.

## Reproducibility and output

`simulation_summary.json` records the applied modules in execution order.
Configured modules keep their existing built-in type and options. Each custom
entry records `Origin="Custom"`, its full MATLAB class name in `Type`, and the
caller-provided `Descriptor`. The same value is available as
`result.AppliedPositionErrorChain`.

The resolved TOML configuration alone is therefore not sufficient to replay a
custom-module run. Archive or revision-control the research module code and
ensure that its source revision, parameters, and component-owned seeds agree
with the recorded descriptor.
