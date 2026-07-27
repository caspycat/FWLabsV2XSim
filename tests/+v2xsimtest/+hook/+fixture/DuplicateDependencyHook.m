classdef DuplicateDependencyHook < v2xsim.hook.Hook
    %DUPLICATEDEPENDENCYHOOK Hook requesting one dependency twice.

    properties (Constant, Access = protected)
        DependencyTypes = [ ...
            ?v2xsim.hook.dependencies.OutputDirectory, ...
            ?v2xsim.hook.dependencies.OutputDirectory]
    end

    methods
        function obj = build(obj, varargin)
        end

        function [obj, invocation] = invoke(obj, invocation)
        end
    end
end
