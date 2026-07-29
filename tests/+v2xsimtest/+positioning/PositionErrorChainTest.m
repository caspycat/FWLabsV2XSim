classdef PositionErrorChainTest < matlab.unittest.TestCase
    %POSITIONERRORCHAINTEST Tests ordered position-error composition.

    methods (Test)
        function testAppliesModulesFromLeftToRight(testCase)
            addOne = ...
                v2xsimtest.positioning.fixture.PositionErrorModuleStub( ...
                    @(value, ~) testCase.addToX(value, 1));
            doubleX = ...
                v2xsimtest.positioning.fixture.PositionErrorModuleStub( ...
                    @(value, ~) testCase.multiplyX(value, 2));
            chain = v2xsim.positioning.PositionErrorChain( ...
                {addOne, doubleX});
            positions = testCase.createPositions();
            context = testCase.createContext(positions, 3);

            [chain, actualPositions] = chain.apply(positions, context);

            expectedPositions = positions;
            expectedPositions.X = (positions.X + 1) .* 2;
            testCase.verifyEqual(actualPositions, expectedPositions);
            testCase.verifyEqual( ...
                chain.Modules{1}.LastSimulationTimeSeconds, 3);
            testCase.verifyEqual( ...
                chain.Modules{2}.LastSimulationTimeSeconds, 3);
        end

        function testRetainsUpdatedModuleStateBetweenApplications(testCase)
            module = ...
                v2xsimtest.positioning.fixture.PositionErrorModuleStub( ...
                    @(value, ~) value);
            chain = v2xsim.positioning.PositionErrorChain({module});
            positions = testCase.createPositions();

            chain = chain.apply( ...
                positions, testCase.createContext(positions, 0));
            chain = chain.apply( ...
                positions, testCase.createContext(positions, 1));

            testCase.verifyEqual( ...
                chain.Modules{1}.ApplicationCount, 2);
        end

        function testEmptyChainLeavesPositionsUnchanged(testCase)
            chain = v2xsim.positioning.PositionErrorChain();
            positions = testCase.createPositions();
            context = testCase.createContext(positions, 0);

            [chain, actualPositions] = chain.apply(positions, context);

            testCase.verifyEqual(actualPositions, positions);
            testCase.verifyEmpty(chain.Modules);
        end

        function testConstructorRejectsNonmoduleElement(testCase)
            constructor = @() ...
                v2xsim.positioning.PositionErrorChain({42});

            testCase.verifyError( ...
                constructor, ...
                "v2xsim:positioning:InvalidErrorModule");
        end

        function testChainIsAnOrchestratorRatherThanModule(testCase)
            chain = v2xsim.positioning.PositionErrorChain();

            testCase.verifyFalse(isa( ...
                chain, "v2xsim.positioning.PositionErrorModule"));
        end

        function testConstructorRejectsNestedChain(testCase)
            nested = v2xsim.positioning.PositionErrorChain();

            testCase.verifyError( ...
                @() v2xsim.positioning.PositionErrorChain({nested}), ...
                "v2xsim:positioning:InvalidErrorModule");
        end

        function testAggregatesModuleDiagnosticsInChainOrder(testCase)
            addOne = ...
                v2xsimtest.positioning.fixture.PositionErrorModuleStub( ...
                    @(value, ~) testCase.addToX(value, 1));
            doubleX = ...
                v2xsimtest.positioning.fixture.PositionErrorModuleStub( ...
                    @(value, ~) testCase.multiplyX(value, 2));
            chain = v2xsim.positioning.PositionErrorChain( ...
                {addOne, doubleX});
            positions = testCase.createPositions();

            [~, ~, diagnostics] = chain.apply( ...
                positions, testCase.createContext(positions, 0));

            testCase.verifyEqual(height(diagnostics), 4);
            testCase.verifyEqual( ...
                diagnostics.ModuleIndex, [1; 1; 2; 2]);
            testCase.verifyEqual( ...
                diagnostics.DisplacementXMeters, ...
                [1; 1; 11; 21]);
        end

        function testDownstreamModuleHandlesUpstreamRowReordering( ...
                testCase)
            reverseRows = ...
                v2xsimtest.positioning.fixture.PositionErrorModuleStub( ...
                    @(value, ~) flipud(value));
            addTen = ...
                v2xsimtest.positioning.fixture.PositionErrorModuleStub( ...
                    @(value, ~) testCase.addToX(value, 10));
            chain = v2xsim.positioning.PositionErrorChain( ...
                {reverseRows, addTen});
            positions = testCase.createPositions();

            [~, outputPositions, diagnostics] = chain.apply( ...
                positions, testCase.createContext(positions, 0));

            testCase.verifyEqual( ...
                string(outputPositions.Properties.RowNames), ...
                ["vehicle-2"; "vehicle-1"]);
            testCase.verifyEqual( ...
                outputPositions("vehicle-1", :).X, 20);
            testCase.verifyEqual( ...
                outputPositions("vehicle-2", :).X, 30);
            secondModuleRows = diagnostics.ModuleIndex == 2;
            testCase.verifyEqual( ...
                diagnostics.VehicleId(secondModuleRows), ...
                ["vehicle-2"; "vehicle-1"]);
            testCase.verifyEqual( ...
                diagnostics.DisplacementXMeters(secondModuleRows), ...
                [10; 10]);
        end

        function testEmptyChainReturnsIdentityDiagnostics(testCase)
            chain = v2xsim.positioning.PositionErrorChain();
            positions = testCase.createPositions();

            [~, ~, diagnostics] = chain.apply( ...
                positions, testCase.createContext(positions, 0));

            testCase.verifyEqual(diagnostics.ModuleIndex, zeros(2, 1));
            testCase.verifyEqual( ...
                diagnostics.StatusEffectType, strings(2, 1));
            testCase.verifyEqual( ...
                diagnostics.DisplacementMagnitudeMeters, zeros(2, 1));
        end
    end

    methods (Access = private)
        function positions = createPositions(~)
            positions = table( ...
                [10; 20], [30; 40], ...
                VariableNames=["X", "Y"], ...
                RowNames=["vehicle-1", "vehicle-2"]);
        end

        function positions = addToX(~, positions, offset)
            positions.X = positions.X + offset;
        end

        function positions = multiplyX(~, positions, multiplier)
            positions.X = positions.X .* multiplier;
        end

        function context = createContext( ...
                ~, actualPositions, simulationTimeSeconds)
            context = v2xsim.positioning.PositionErrorContext( ...
                actualPositions, simulationTimeSeconds, 0.1, 10);
        end
    end
end
