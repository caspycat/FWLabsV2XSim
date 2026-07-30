function mustBeRandomSeeds(value)
%MUSTBERANDOMSEEDS Validate seeds accepted by component-owned MT19937 streams.

if any(value > double(intmax("uint32")), "all")
    error( ...
        "v2xsimregression:bazzi2020blindspots:InvalidRandomSeed", ...
        "Random seeds must be integers in the uint32 range.");
end
end
