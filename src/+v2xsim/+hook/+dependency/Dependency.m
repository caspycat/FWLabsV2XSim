classdef (Abstract, HandleCompatible) Dependency
    %DEPENDENCY Base type for data and services injected into hooks.
    %   Dependencies are value classes by default. Implementations that
    %   represent a shared mutable service may additionally inherit from
    %   handle.
end
