classdef (Abstract, HandleCompatible) Hook
    %HOOK User-supplied behavior invoked at a simulator hook point.
    %   Hooks are value classes by default. BUILD, INVOKE, and CLEANUP
    %   return the updated hook so a caller can retain value-class state.

    properties (Abstract, Constant, Access = protected)
        %DEPENDENCYTYPES Ordered dependency types received by BUILD.
        DependencyTypes (1, :) matlab.metadata.Class
    end

    methods (Sealed)
        function dependencyTypes = dependencies(obj)
            %DEPENDENCIES Return and validate declared dependency types.
            arguments (Input)
                obj (1, 1)
            end
            arguments (Output)
                dependencyTypes (1, :) matlab.metadata.Class
            end

            dependencyTypes = obj.DependencyTypes;
            dependencyNames = strings(1, numel(dependencyTypes));
            baseType = ?v2xsim.hook.dependency.Dependency;
            for dependencyIndex = 1:numel(dependencyTypes)
                dependencyType = dependencyTypes(dependencyIndex);
                if ~(dependencyType <= baseType)
                    error( ...
                        "v2xsim:hook:InvalidDependencyDeclaration", ...
                        "DependencyTypes entry %d must identify a " + ...
                        "subclass of v2xsim.hook.dependency.Dependency.", ...
                        dependencyIndex);
                end
                dependencyNames(dependencyIndex) = ...
                    dependencyType.Name;
            end

            if numel(unique(dependencyNames)) ~= ...
                    numel(dependencyNames)
                error( ...
                    "v2xsim:hook:DuplicateDependencyDeclaration", ...
                    "A hook may request each dependency type only once.");
            end
        end
    end

    methods
        function obj = cleanup(obj)
            %CLEANUP Finalize resources or accumulated hook results.
            %   The default implementation does nothing.
            arguments (Input)
                obj (1, 1)
            end
        end
    end

    methods (Abstract)
        %BUILD Receive dependencies in DependencyTypes order.
        obj = build(obj, varargin)

        %INVOKE Run this hook for one invocation.
        [obj, invocation] = invoke(obj, invocation)
    end
end
