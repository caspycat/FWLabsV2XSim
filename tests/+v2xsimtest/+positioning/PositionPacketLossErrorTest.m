classdef PositionPacketLossErrorTest < matlab.unittest.TestCase
    %POSITIONPACKETLOSSERRORTEST Tests per-identity network sample-and-hold.

    methods (Test)
        function testFullLossHoldsBootstrapPosition(testCase)
            module = v2xsim.positioning.PositionPacketLossError(1);
            initial = testCase.createPositions("vehicle-1", 10);
            current = testCase.createPositions("vehicle-1", 20);

            [module, initialOutput, initialDiagnostics] = module.apply( ...
                initial, testCase.createContext(initial, 0));
            [~, currentOutput, currentDiagnostics] = module.apply( ...
                current, testCase.createContext(current, 1));

            testCase.verifyEqual(initialOutput, initial);
            testCase.verifyEqual(currentOutput.X, initial.X);
            testCase.verifyEqual( ...
                initialDiagnostics.NetworkUpdateOutcome, ...
                "BootstrapReceived");
            testCase.verifyEqual( ...
                currentDiagnostics.NetworkUpdateOutcome, "Dropped");
            testCase.verifyEqual( ...
                currentDiagnostics.OutputSourceTimeSeconds, 0);
            testCase.verifyEqual(currentDiagnostics.OutputAgeSeconds, 1);
        end

        function testZeroLossAlwaysUsesCurrentPosition(testCase)
            module = v2xsim.positioning.PositionPacketLossError(0);
            initial = testCase.createPositions("vehicle-1", 10);
            current = testCase.createPositions("vehicle-1", 20);
            module = module.apply( ...
                initial, testCase.createContext(initial, 0));

            [~, output, diagnostics] = module.apply( ...
                current, testCase.createContext(current, 1));

            testCase.verifyEqual(output, current);
            testCase.verifyEqual( ...
                diagnostics.NetworkUpdateOutcome, "Received");
            testCase.verifyEqual( ...
                diagnostics.OutputSourceTimeSeconds, 1);
            testCase.verifyEqual(diagnostics.OutputAgeSeconds, 0);
        end

        function testSeededLossesAreAssignedInStableIdentityOrder( ...
                testCase)
            seed = 731;
            probability = 0.5;
            ids = ["vehicle-b"; "vehicle-a"; "vehicle-c"];
            initial = testCase.createPositions(ids, [20; 10; 30]);
            current = testCase.createPositions(ids, [200; 100; 300]);
            module = v2xsim.positioning.PositionPacketLossError( ...
                probability, RandomSeed=seed);
            module = module.apply( ...
                initial, testCase.createContext(initial, 0));
            expectedStream = RandStream("mt19937ar", Seed=seed);
            sortedIds = sort(ids);
            sortedLosses = rand(expectedStream, numel(ids), 1) < ...
                probability;
            [~, sortedIndices] = ismember(ids, sortedIds);
            expectedLosses = sortedLosses(sortedIndices);

            [~, output, diagnostics] = module.apply( ...
                current, testCase.createContext(current, 1));

            expected = current;
            expected.X(expectedLosses) = initial.X(expectedLosses);
            expected.Y(expectedLosses) = initial.Y(expectedLosses);
            expectedOutcomes = repmat("Received", numel(ids), 1);
            expectedOutcomes(expectedLosses) = "Dropped";
            testCase.verifyEqual(output, expected);
            testCase.verifyEqual( ...
                diagnostics.NetworkUpdateOutcome, expectedOutcomes);
        end

        function testLossesAreInvariantToInputRowOrder(testCase)
            firstInitial = testCase.createPositions( ...
                ["vehicle-b"; "vehicle-a"; "vehicle-c"], ...
                [20; 10; 30]);
            secondInitial = flipud(firstInitial);
            firstCurrent = testCase.createPositions( ...
                ["vehicle-b"; "vehicle-a"; "vehicle-c"], ...
                [200; 100; 300]);
            secondCurrent = flipud(firstCurrent);
            firstModule = v2xsim.positioning.PositionPacketLossError( ...
                0.5, RandomSeed=811);
            secondModule = v2xsim.positioning.PositionPacketLossError( ...
                0.5, RandomSeed=811);
            firstModule = firstModule.apply( ...
                firstInitial, testCase.createContext(firstInitial, 0));
            secondModule = secondModule.apply( ...
                secondInitial, testCase.createContext(secondInitial, 0));

            [~, firstOutput] = firstModule.apply( ...
                firstCurrent, testCase.createContext(firstCurrent, 1));
            [~, secondOutput] = secondModule.apply( ...
                secondCurrent, testCase.createContext(secondCurrent, 1));

            testCase.verifyEqual( ...
                string(firstOutput.Properties.RowNames), ...
                string(firstCurrent.Properties.RowNames));
            testCase.verifyEqual( ...
                string(secondOutput.Properties.RowNames), ...
                string(secondCurrent.Properties.RowNames));
            testCase.verifyEqual( ...
                firstOutput, ...
                secondOutput(firstOutput.Properties.RowNames, :));
        end

        function testSameTimeReusesDecisionAndLatestReceivedInput( ...
                testCase)
            ids = "vehicle-" + string((1:16).');
            initial = testCase.createPositions(ids, (1:16).');
            firstAtOne = testCase.createPositions(ids, (101:116).');
            revisedAtOne = testCase.createPositions(ids, (201:216).');
            atTwo = testCase.createPositions(ids, (301:316).');
            repeated = v2xsim.positioning.PositionPacketLossError( ...
                0.5, RandomSeed=991);
            reference = repeated;
            repeated = repeated.apply( ...
                initial, testCase.createContext(initial, 0));
            reference = reference.apply( ...
                initial, testCase.createContext(initial, 0));

            [repeated, ~, firstDiagnostics] = repeated.apply( ...
                firstAtOne, testCase.createContext(firstAtOne, 1));
            [repeated, revisedOutput, revisedDiagnostics] = ...
                repeated.apply( ...
                    revisedAtOne, ...
                    testCase.createContext(revisedAtOne, 1));
            [reference, referenceOutput] = reference.apply( ...
                revisedAtOne, testCase.createContext(revisedAtOne, 1));

            testCase.verifyEqual( ...
                revisedDiagnostics.NetworkUpdateOutcome, ...
                firstDiagnostics.NetworkUpdateOutcome);
            testCase.verifyEqual(revisedOutput, referenceOutput);

            [~, repeatedNext] = repeated.apply( ...
                atTwo, testCase.createContext(atTwo, 2));
            [~, referenceNext] = reference.apply( ...
                atTwo, testCase.createContext(atTwo, 2));
            testCase.verifyEqual(repeatedNext, referenceNext);
        end

        function testSameTimeBootstrapKeepsOutcomeAndLatestInput( ...
                testCase)
            module = v2xsim.positioning.PositionPacketLossError(1);
            initial = testCase.createPositions("vehicle-1", 10);
            revised = testCase.createPositions("vehicle-1", 15);
            later = testCase.createPositions("vehicle-1", 20);
            module = module.apply( ...
                initial, testCase.createContext(initial, 0));

            [module, revisedOutput, revisedDiagnostics] = module.apply( ...
                revised, testCase.createContext(revised, 0));
            [~, laterOutput, laterDiagnostics] = module.apply( ...
                later, testCase.createContext(later, 1));

            testCase.verifyEqual(revisedOutput, revised);
            testCase.verifyEqual( ...
                revisedDiagnostics.NetworkUpdateOutcome, ...
                "BootstrapReceived");
            testCase.verifyEqual( ...
                revisedDiagnostics.OutputSourceTimeSeconds, 0);
            testCase.verifyEqual(laterOutput.X, revised.X);
            testCase.verifyEqual( ...
                laterDiagnostics.NetworkUpdateOutcome, "Dropped");
            testCase.verifyEqual( ...
                laterDiagnostics.OutputSourceTimeSeconds, 0);
            testCase.verifyEqual(laterDiagnostics.OutputAgeSeconds, 1);
        end

        function testEntrantsBootstrapAndReappearingIdentityRetainsState( ...
                testCase)
            module = v2xsim.positioning.PositionPacketLossError(1);
            initial = testCase.createPositions("vehicle-a", 10);
            withEntrant = testCase.createPositions( ...
                ["vehicle-a"; "vehicle-b"], [20; 30]);
            onlyEntrant = testCase.createPositions("vehicle-b", 40);
            reappeared = testCase.createPositions("vehicle-a", 50);
            module = module.apply( ...
                initial, testCase.createContext(initial, 0));

            [module, entrantOutput, entrantDiagnostics] = module.apply( ...
                withEntrant, testCase.createContext(withEntrant, 1));
            module = module.apply( ...
                onlyEntrant, testCase.createContext(onlyEntrant, 2));
            [~, reappearedOutput, reappearedDiagnostics] = module.apply( ...
                reappeared, testCase.createContext(reappeared, 3));

            testCase.verifyEqual(entrantOutput.X, [10; 30]);
            testCase.verifyEqual( ...
                entrantDiagnostics.NetworkUpdateOutcome, ...
                ["Dropped"; "BootstrapReceived"]);
            testCase.verifyEqual(reappearedOutput.X, 10);
            testCase.verifyEqual( ...
                reappearedDiagnostics.NetworkUpdateOutcome, "Dropped");
            testCase.verifyEqual( ...
                reappearedDiagnostics.OutputSourceTimeSeconds, 0);
            testCase.verifyEqual( ...
                reappearedDiagnostics.OutputAgeSeconds, 3);
        end

        function testEmptyInputAdvancesTimeWithoutDecidingEntrants( ...
                testCase)
            module = v2xsim.positioning.PositionPacketLossError(1);
            emptyPositions = testCase.createPositions( ...
                strings(0, 1), zeros(0, 1));

            [module, emptyOutput, diagnostics] = module.apply( ...
                emptyPositions, ...
                testCase.createContext(emptyPositions, 1));
            entrant = testCase.createPositions("vehicle-1", 10);
            [~, entrantOutput, entrantDiagnostics] = module.apply( ...
                entrant, testCase.createContext(entrant, 1));

            testCase.verifyEqual(emptyOutput, emptyPositions);
            testCase.verifyEmpty(diagnostics);
            testCase.verifyEqual(entrantOutput, entrant);
            testCase.verifyEqual( ...
                entrantDiagnostics.NetworkUpdateOutcome, ...
                "BootstrapReceived");
        end

        function testRejectsDecreasingSimulationTimeWithoutStateChange( ...
                testCase)
            positions = testCase.createPositions( ...
                "vehicle-" + string((1:16).'), (1:16).');
            module = v2xsim.positioning.PositionPacketLossError( ...
                0.5, RandomSeed=1217);
            module = module.apply( ...
                positions, testCase.createContext(positions, 1));
            reference = module;

            testCase.verifyError( ...
                @() module.apply( ...
                    positions, testCase.createContext(positions, 0.5)), ...
                "v2xsim:positioning:" + ...
                "PositionPacketLossTimeReversed");

            later = testCase.createPositions( ...
                string(positions.Properties.RowNames), (101:116).');
            [~, actual] = module.apply( ...
                later, testCase.createContext(later, 2));
            [~, expected] = reference.apply( ...
                later, testCase.createContext(later, 2));
            testCase.verifyEqual(actual, expected);
        end

        function testCopiedModulesOwnIndependentRandomStreams(testCase)
            ids = "vehicle-" + string((1:64).');
            initial = testCase.createPositions(ids, (1:64).');
            current = testCase.createPositions(ids, (101:164).');
            original = v2xsim.positioning.PositionPacketLossError( ...
                0.5, RandomSeed=1553);
            original = original.apply( ...
                initial, testCase.createContext(initial, 0));
            firstCopy = original;
            secondCopy = original;

            [~, firstOutput] = firstCopy.apply( ...
                current, testCase.createContext(current, 1));
            [~, secondOutput] = secondCopy.apply( ...
                current, testCase.createContext(current, 1));

            testCase.verifyEqual(firstOutput, secondOutput);
        end

        function testDoesNotAdvanceGlobalOrSuppliedStream(testCase)
            originalGlobalState = rng;
            testCase.addTeardown(@() rng(originalGlobalState));
            rng(91);
            expectedGlobalState = rng;
            suppliedStream = RandStream("mt19937ar", Seed=55);
            expectedSuppliedState = suppliedStream.State;
            ids = "vehicle-" + string((1:8).');
            initial = testCase.createPositions(ids, (1:8).');
            current = testCase.createPositions(ids, (11:18).');
            module = v2xsim.positioning.PositionPacketLossError( ...
                0.5, RandomStream=suppliedStream);
            module = module.apply( ...
                initial, testCase.createContext(initial, 0));

            module.apply(current, testCase.createContext(current, 1));

            testCase.verifyEqual(rng, expectedGlobalState);
            testCase.verifyEqual( ...
                suppliedStream.State, expectedSuppliedState);
        end

        function testPreservesInputCoordinateTypes(testCase)
            module = v2xsim.positioning.PositionPacketLossError(1);
            initial = testCase.createPositions("vehicle-1", 10);
            initial.X = single(initial.X);
            current = testCase.createPositions("vehicle-1", 20);
            current.X = single(current.X);
            module = module.apply( ...
                initial, testCase.createContext(initial, 0));

            [~, output] = module.apply( ...
                current, testCase.createContext(current, 1));

            testCase.verifyClass(output.X, "single");
            testCase.verifyClass(output.Y, "double");
            testCase.verifyEqual(output.X, initial.X);
            testCase.verifyEqual(output.Y, initial.Y);
        end

        function testHoldsOutputOfPrecedingModule(testCase)
            addHundred = ...
                v2xsimtest.positioning.fixture.PositionErrorModuleStub( ...
                    @(positions, ~) ...
                    testCase.addToX(positions, 100));
            packetLoss = ...
                v2xsim.positioning.PositionPacketLossError(1);
            chain = v2xsim.positioning.PositionErrorChain( ...
                {addHundred, packetLoss});
            initial = testCase.createPositions("vehicle-1", 0);
            current = testCase.createPositions("vehicle-1", 5);
            chain = chain.apply( ...
                initial, testCase.createContext(initial, 0));

            [~, output] = chain.apply( ...
                current, testCase.createContext(current, 1));

            testCase.verifyEqual(output.X, 100);
        end

        function testRejectsInvalidProbabilityAndSeed(testCase)
            testCase.verifyError( ...
                @() v2xsim.positioning.PositionPacketLossError(1.01), ...
                "v2xsim:positioning:InvalidLossProbability");
            testCase.verifyError( ...
                @() v2xsim.positioning.PositionPacketLossError( ...
                    0.5, RandomSeed=2^32), ...
                "v2xsim:positioning:InvalidRandomSeed");
        end
    end

    methods (Access = private)
        function positions = createPositions(~, ids, x)
            ids = reshape(string(ids), [], 1);
            x = reshape(double(x), [], 1);
            positions = table( ...
                x, x + 100, ...
                VariableNames=["X", "Y"]);
            if ~isempty(ids)
                positions.Properties.RowNames = cellstr(ids);
            end
        end

        function context = createContext( ...
                ~, actualPositions, simulationTimeSeconds)
            context = v2xsim.positioning.PositionErrorContext( ...
                actualPositions, simulationTimeSeconds, 0.5, 10);
        end

        function positions = addToX(~, positions, offset)
            positions.X = positions.X + offset;
        end
    end
end
