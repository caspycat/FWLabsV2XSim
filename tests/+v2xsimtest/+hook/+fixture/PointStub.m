classdef PointStub < v2xsim.hook.point.Point
    %POINTSTUB Hook point for registry tests.

    enumeration
        Test
        Other
    end

    methods (Access = protected)
        function invocationType = declaredInvocationType(~)
            invocationType = ...
                ?v2xsimtest.hook.fixture.InvocationStub;
        end
    end
end
