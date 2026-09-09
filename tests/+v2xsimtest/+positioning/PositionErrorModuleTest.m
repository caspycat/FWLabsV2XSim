classdef PositionErrorModuleTest < matlab.unittest.TestCase
    %POSITIONERRORMODULETEST Tests the position error module contract.

    methods (Test)
        function testApplyReturnsTransformedPositionsAndUpdatedState( ...
                testCase)
            positions = testCase.createPositions();
            module = ...
                v2xsimtest.positioning.fixture.PositionErrorModuleStub( ...
                    @(value, ~) testCase.offsetPositions(value, [2, -3]));
            context = testCase.createContext(positions, 1.25);

            [module, actualPositions] = module.apply(positions, context);

            expectedPositions = testCase.offsetPositions(positions, [2, -3]);
            testCase.verifyEqual(actualPositions, expectedPositions);
            testCase.verifyEqual(module.ApplicationCount, 1);
            testCase.verifyEqual(module.LastSimulationTimeSeconds, 1.25);
        end

        function testApplyRejectsInvalidInputSchema(testCase)
            positions = testCase.createPositions();
            context = testCase.createContext(positions, 0);
            positions.Z = zeros(height(positions), 1);
            module = testCase.createIdentityModule();

            testCase.verifyError( ...
                @() module.apply(positions, context), ...
                "v2xsim:positioning:MustBe2DPositionTable");
        end

        function testApplyRejectsNonfiniteCoordinates(testCase)
            positions = testCase.createPositions();
            context = testCase.createContext(positions, 0);
            positions.X(1) = Inf;
            module = testCase.createIdentityModule();

            testCase.verifyError( ...
                @() module.apply(positions, context), ...
                "v2xsim:positioning:MustBe2DPositionTable");
        end

        function testApplyRejectsMissingVehicleIdentities(testCase)
            positions = testCase.createPositions();
            context = testCase.createContext(positions, 0);
            positions.Properties.RowNames = {};
            module = testCase.createIdentityModule();

            testCase.verifyError( ...
                @() module.apply(positions, context), ...
                "v2xsim:positioning:MustBe2DPositionTable");
        end

        function testContextRejectsNegativeSimulationTime(testCase)
            positions = testCase.createPositions();

            testCase.verifyFunctionThrows( ...
                @() v2xsim.positioning.PositionErrorContext( ...
                    positions, -0.1, 0.1, 10));
        end

        function testApplyRejectsInvalidOutputSchema(testCase)
            positions = testCase.createPositions();
            context = testCase.createContext(positions, 0);
            module = ...
                v2xsimtest.positioning.fixture.PositionErrorModuleStub( ...
                    @(value, ~) removevars(value, "Y"));

            testCase.verifyError( ...
                @() module.apply(positions, context), ...
                "v2xsim:positioning:MustBe2DPositionTable");
        end

        function testApplyRejectsChangedVehicleSet(testCase)
            positions = testCase.createPositions();
            context = testCase.createContext(positions, 0);
            module = ...
                v2xsimtest.positioning.fixture.PositionErrorModuleStub( ...
                    @(value, ~) testCase.renameFirstVehicle(value));

            testCase.verifyError( ...
                @() module.apply(positions, context), ...
                "v2xsim:positioning:VehicleSetChanged");
        end

        function testApplyAllowsVehicleRowReordering(testCase)
            positions = testCase.createPositions();
            context = testCase.createContext(positions, 0);
            module = ...
                v2xsimtest.positioning.fixture.PositionErrorModuleStub( ...
                    @(value, ~) flipud(value));

            [~, actualPositions] = module.apply(positions, context);

            testCase.verifyEqual(actualPositions, flipud(positions));
        end

        function testApplyAllowsEmptyPositionSnapshot(testCase)
            positions = table( ...
                zeros(0, 1), zeros(0, 1), ...
                VariableNames=["X", "Y"]);
            context = testCase.createContext(positions, 0);
            module = testCase.createIdentityModule();

            [~, actualPositions] = module.apply(positions, context);

            testCase.verifyEqual(actualPositions, positions);
        end

        function testDiagnosticsNormalizeSinglePositionsToDouble( ...
                testCase)
            positions = testCase.createPositions();
            positions.X = single(positions.X);
            positions.Y = single(positions.Y);
            context = testCase.createContext(positions, 0);
            module = testCase.createIdentityModule();

            [~, actualPositions, diagnostics] = ...
                module.apply(positions, context);

            testCase.verifyClass(actualPositions.X, "single");
            testCase.verifyClass(actualPositions.Y, "single");
            numericNames = [ ...
                "InputXMeters", "InputYMeters", ...
                "OutputXMeters", "OutputYMeters", ...
                "DisplacementXMeters", "DisplacementYMeters", ...
                "DisplacementMagnitudeMeters"];
            for numericName = numericNames
                testCase.verifyClass( ...
                    diagnostics.(numericName), "double");
            end
            testCase.verifyEqual( ...
                diagnostics.NetworkUpdateOutcome, strings(2, 1));
            testCase.verifyTrue(all(isnan( ...
                diagnostics.OutputSourceTimeSeconds)));
            testCase.verifyTrue(all(isnan( ...
                diagnostics.OutputAgeSeconds)));
        end

        function testApplyRejectsMismatchedContextVehicles(testCase)
            positions = testCase.createPositions();
            actualPositions = positions;
            actualPositions.Properties.RowNames{1} = 'other-vehicle';
            context = testCase.createContext(actualPositions, 0);
            module = testCase.createIdentityModule();

            testCase.verifyError( ...
                @() module.apply(positions, context), ...
                "v2xsim:positioning:ContextVehicleSetMismatch");
        end
    end

    methods (Access = private)
        function module = createIdentityModule(~)
            module = ...
                v2xsimtest.positioning.fixture.PositionErrorModuleStub( ...
                    @(value, ~) value);
        end

        function positions = createPositions(~)
            positions = table( ...
                [10; 20], [30; 40], ...
                VariableNames=["X", "Y"], ...
                RowNames=["vehicle-1", "vehicle-2"]);
        end

        function context = createContext( ...
                ~, actualPositions, simulationTimeSeconds)
            context = v2xsim.positioning.PositionErrorContext( ...
                actualPositions, simulationTimeSeconds, 0.1, 10);
        end

        function positions = offsetPositions(~, positions, offset)
            positions.X = positions.X + offset(1);
            positions.Y = positions.Y + offset(2);
        end

        function positions = renameFirstVehicle(~, positions)
            rowNames = positions.Properties.RowNames;
            rowNames{1} = 'other-vehicle';
            positions.Properties.RowNames = rowNames;
        end

        function verifyFunctionThrows(testCase, functionHandle)
            didThrow = false;
            try
                functionHandle();
            catch
                didThrow = true;
            end

            testCase.verifyTrue(didThrow, ...
                "Expected the function to throw an exception.");
        end
    end
end
