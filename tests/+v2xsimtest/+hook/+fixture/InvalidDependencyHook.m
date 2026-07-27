classdef InvalidDependencyHook < v2xsim.hook.Hook
    %INVALIDDEPENDENCYHOOK Hook with an invalid dependency declaration.

    properties (Constant, Access = protected)
        DependencyTypes = ?string
    end

    methods
        function obj = build(obj, varargin)
        end

        function [obj, invocation] = invoke(obj, invocation)
        end
    end
end
