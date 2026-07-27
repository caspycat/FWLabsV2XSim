# Simulator parameters in V7

WiLabV2Xsim V7 uses dotted public parameter names. The names apply equally to
configuration files and MATLAB name-value arguments. For example:

```matlab
WiLabV2Xsim("default", ...
    "simulation.DurationSeconds", 10, ...
    "simulation.RadioAccessMode", "NR-V2X", ...
    "nrV2x.Mcs", 7);
```

The internal `simParams`, `appParams`, `phyParams`, and `outParams` fields
retain their V6 layout. Public naming is translated at the input boundary so the
namespace migration does not also rewrite the simulation engine. V6 names are
accepted as deprecated aliases during the V7 compatibility cycle. Supplying both
a V7 name and its V6 alias is an error. Using a V6 alias emits the MATLAB
warning `v2xsim:parameters:DeprecatedV6Name` with the replacement V7 name.
New configurations must use V7 names.

## Namespace guide

| Namespace | Purpose |
|---|---|
| `simulation` | Run identity, duration, random seed, and selected radio-access mode. |
| `scenario` | Scenario selection and global mobility-update timing. |
| `scenarioOptions` | Constructor options passed directly to the selected traffic scenario. |
| `positioning` | Ordered positioning-error models and their settings. |
| `application` | Packet generation, CAM timing, packet size, and application resource demand. |
| `channelLoad` | Technology-neutral scheduling of channel-load measurements; each radio computes load differently. |
| `congestionControl` | Master switch for congestion control shared by the technology-specific implementations. |
| `radio` | Radio settings shared by more than one access technology. |
| `awareness` | Distances over which awareness and reception statistics are evaluated. |
| `resourcePool` | Time-frequency resources available for direct vehicle communication. |
| `channel` | Propagation, packet-error curves, fading, shadowing, and obstacle attenuation. |
| `ieee80211p` | Generic IEEE 802.11p physical- and MAC-layer behavior. |
| `itsG5` | ETSI ITS-G5 profile behavior built on the IEEE 802.11 access layer. |
| `lteV2x` | LTE-V2X-specific sidelink physical-layer settings. |
| `nrV2x` | NR-V2X-specific sidelink physical-layer settings. |
| `sidelink` | Behavior shared by LTE-V2X and NR-V2X direct PC5 communication. |
| `resourceAllocation` | Controlled and autonomous sidelink resource-selection algorithms. |
| `output` | Output directory and optional metrics or reports. |
| `coexistence` | Joint IEEE 802.11p/ITS-G5 and cellular-sidelink coexistence methods. |
| `infrastructure` | Roadside-unit configuration. |

## Field reference and V6 mapping

### `simulation`

Run identity, duration, random seed, and selected radio-access mode.

| V7 field | V6 field | Type | Description |
|---|---|---|---|
| `simulation.RequiredVersion` | `CheckVersion` | `string` | Simulator version needed |
| `simulation.RandomSeed` | `seed` | `integer` | Seed for random numbers |
| `simulation.DurationSeconds` | `simulationTime` | `double` | Simulation duration (s) |
| `simulation.RadioAccessMode` | `Technology` | `string` | Choose radio access technology to simulate: "LTE-V2X", "80211p", "COEX-NO-INTERF", "COEX-STD-INTERF", "NR-V2X"/"5G-V2X", "COEX-STD-INTERF-5G" |
| `simulation.RunLabel` | `message` | `string` | Message during simulation |

### `scenario`

Scenario selection and global mobility-update timing.

| V7 field | V6 field | Type | Description |
|---|---|---|---|
| `scenario.Type` | `typeOfScenario` | `string` | Scenario class name |
| `scenario.UpdateIntervalSeconds` | `positionTimeResolution` | `double` | Time resolution for the positioning update of the vehicles in the trace file (s) |

### `scenarioOptions`

Constructor options passed directly to the selected traffic scenario.

| V7 field | V6 field | Type | Description |
|---|---|---|---|
| `scenarioOptions.VehicleCount` | `scenarioOptions.VehicleCount` | `integer` | Number of vehicles |
| `scenarioOptions.SimulationAreaSize` | `scenarioOptions.SimulationAreaSize` | `double` | Square simulation area side length (m) |
| `scenarioOptions.MeanVehicleSpeed` | `scenarioOptions.MeanVehicleSpeed` | `double` | Mean vehicle speed (m/s) |
| `scenarioOptions.VehicleSpeedStandardDeviation` | `scenarioOptions.VehicleSpeedStandardDeviation` | `double` | Vehicle speed standard deviation (m/s) |
| `scenarioOptions.NLanes` | `scenarioOptions.NLanes` | `integer` | Number of lanes per direction |
| `scenarioOptions.LaneWidth` | `scenarioOptions.LaneWidth` | `double` | Lane width (m) |
| `scenarioOptions.RoadLength` | `scenarioOptions.RoadLength` | `double` | Road length (m) |
| `scenarioOptions.CentralDividerWidth` | `scenarioOptions.CentralDividerWidth` | `double` | Central divider width (m) |
| `scenarioOptions.RerollSpeedOnWrapAround` | `scenarioOptions.RerollSpeedOnWrapAround` | `bool` | Reroll speed after wraparound |
| `scenarioOptions.TrafficModel` | `scenarioOptions.TrafficModel` | `string` | ETSI traffic model |
| `scenarioOptions.Placement` | `scenarioOptions.Placement` | `string` | ETSI longitudinal placement model |
| `scenarioOptions.MinimumRoadLength` | `scenarioOptions.MinimumRoadLength` | `double` | Minimum road length (m) |
| `scenarioOptions.ExitProbability` | `scenarioOptions.ExitProbability` | `double` | Probability of taking the exit ramp |
| `scenarioOptions.MergeDistance` | `scenarioOptions.MergeDistance` | `double` | Longitudinal merge distance (m) |

### `positioning`

Ordered positioning-error models and their settings.

| V7 field | V6 field | Type | Description |
|---|---|---|---|
| `positioning.ErrorModules` | `positionErrorModules` | `string` | Ordered position error modules |
| `positioning.Gaussian.StandardDeviationMeters` | `positionErrorOptions.Gaussian.StandardDeviationMeters` | `double` | Gaussian radial standard deviation (m) |
| `positioning.Delay.DelaySeconds` | `positionErrorOptions.Delay.DelaySeconds` | `double` | Position observation delay (s) |
| `positioning.FalseExit.AffectedVehicleProbability` | `positionErrorOptions.FalseExit.CurseProbability` | `double` | Fraction of vehicles affected by this route-perception error |
| `positioning.FalseExit.ResetAfterSeconds` | `positionErrorOptions.FalseExit.ResetAfterSeconds` | `double` | Time before the route-perception error resets, in seconds |
| `positioning.FalseMerge.AffectedVehicleProbability` | `positionErrorOptions.FalseMerge.CurseProbability` | `double` | Fraction of vehicles affected by this route-perception error |
| `positioning.FalseMerge.ResetAfterSeconds` | `positionErrorOptions.FalseMerge.ResetAfterSeconds` | `double` | Time before the route-perception error resets, in seconds |

### `application`

Packet generation, CAM timing, packet size, and application resource demand.

| V7 field | V6 field | Type | Description |
|---|---|---|---|
| `application.ResourceReservationIntervalSeconds` | `allocationPeriod` | `double` | Resource allocation period (s) |
| `application.PacketGeneration.IntervalVariationSeconds` | `variabilityGenerationInterval` | `double` | Variability of beacon period per vehicle (s) (only 11p) |
| `application.Cam.IntervalDiscretization` | `camDiscretizationType` | `string` | Type of discretization - it can be "allSteps" or "allocationAligned" if not "null" (continuous) |
| `application.Cam.MaximumIntervalIncreasePercent` | `camDiscretizationIncrease` | `double` | Percentage of the admissibile increase of the generation interval |
| `application.PacketGeneration.IntervalSeconds` | `generationInterval` | `double` | Packet generation interval per each vehicle (s) |
| `application.PacketGeneration.RandomComponentMeanSeconds` | `generationIntervalAverageRandomPart` | `double` | Average Random part Packet generation interval (s) |
| `application.PacketSizeBytes` | `beaconSizeBytes` | `integer` | Beacon size (Bytes) |

### `channelLoad`

Technology-neutral scheduling of channel-load measurements; each radio computes load differently.

| V7 field | V6 field | Type | Description |
|---|---|---|---|
| `channelLoad.Enabled` | `cbrActive` | `bool` | If CBR calculation enabled |
| `channelLoad.MeasurementWindowSeconds` | `cbrSensingInterval` | `double` | Average duration of the interval for the CBR calculation (s) |
| `channelLoad.UpdateStepsPerWindow` | `cbrSensingIntervalDesynchN` | `integer` | Number of subintervals for the CBR calculation desynch |

### `congestionControl`

Master switch for congestion control shared by the technology-specific implementations.

| V7 field | V6 field | Type | Description |
|---|---|---|---|
| `congestionControl.Enabled` | `dcc_active` | `bool` | If DCC is enabled |

### `radio`

Radio settings shared by more than one access technology.

| V7 field | V6 field | Type | Description |
|---|---|---|---|
| `radio.BandwidthMHz` | `BwMHz` | `double` | Bandwidth (MHz) |
| `radio.TransmitPowerDbm` | `Ptx_dBm` | `double` | Transmitted power (dBm) |
| `radio.FixedPowerDensityEnabled` | `FixedPdensity` | `bool` | Fixed power density (instead of fixed power) |
| `radio.TransmitAntennaGainDb` | `Gt_dB` | `double` | Transmitter antenna gain (dB) |
| `radio.ReceiveAntennaGainDb` | `Gr_dB` | `double` | Receiver antenna gain (dB) |
| `radio.ReceiverNoiseFigureDb` | `F_dB` | `double` | Noise figure of the receiver (dB) |

### `awareness`

Distances over which awareness and reception statistics are evaluated.

| V7 field | V6 field | Type | Description |
|---|---|---|---|
| `awareness.RangesMeters` | `Raw` | `integerOrArrayString` | Awareness range (m) |

### `resourcePool`

Time-frequency resources available for direct vehicle communication.

| V7 field | V6 field | Type | Description |
|---|---|---|---|
| `resourcePool.V2vSharePercent` | `resourcesV2V` | `integer` | Resource allocated to V2V (%) |
| `resourcePool.SubchannelSizeResourceBlocks` | `sizeSubchannel` | `integer` | Subchannel size |
| `resourcePool.MaximumFrequencyDomainBeaconResources` | `NumBeaconsFrequency` | `integer` | Specify the number of BRs in the frequency domain |
| `resourcePool.PartialFrequencyOverlapEnabled` | `BRoverlapAllowed` | `bool` | If a pratial overlap in frequency is allowed |

### `channel`

Propagation, packet-error curves, fading, shadowing, and obstacle attenuation.

| V7 field | V6 field | Type | Description |
|---|---|---|---|
| `channel.PacketErrorRateCurveDirectory` | `folderPERcurves` | `string` | Name of folder with PER vs. SINR curves - Null if thresholds are used |
| `channel.NlosPacketErrorRateCurveDirectory` | `folderPERcurvesNLOS` | `string` | Name of folder with PER vs. SINR curves - Null if thresholds are used |
| `channel.RayleighFadingEnabled` | `fadingRayleigh` | `bool` | Activates uncorrelated Rayleigh fading |
| `channel.PathLoss.Model` | `channelModel` | `integer` | Channel model (0:WINNER+ B1; N: N slopes with N=1,2,3; 4: 5G NLOSv model) |
| `channel.PathLoss.ReferenceLossAtOneMeterDb` | `L0_dB` | `double` | Path loss at 1m (dB) |
| `channel.PathLoss.Exponent1` | `beta` | `double` | Path loss exponent |
| `channel.PathLoss.Exponent2` | `beta2` | `double` | Path loss exponent of the second slope |
| `channel.PathLoss.Exponent3` | `beta3` | `double` | Path loss exponent of the second slope |
| `channel.PathLoss.BreakpointDistance1Meters` | `d_threshold1` | `double` | First distance threshold |
| `channel.PathLoss.BreakpointDistance2Meters` | `d_threshold2` | `double` | Second distance threshold |
| `channel.Obstacles.BuildingAttenuationDbPerMeter` | `Abuild_dB` | `double` | Attenuation every meter inside buildings (dB) |
| `channel.Obstacles.WallAttenuationDb` | `Awall_dB` | `double` | Attenuation for each wall crossed (dB) |
| `channel.Shadowing.LosStandardDeviationDb` | `stdDevShadowLOS_dB` | `integer` | Standard deviation of shadowing in LOS (dB) |
| `channel.Shadowing.NlosStandardDeviationDb` | `stdDevShadowNLOS_dB` | `integer` | Standard deviation of shadowing in NLOS (dB) |

### `ieee80211p`

Generic IEEE 802.11p physical- and MAC-layer behavior.

| V7 field | V6 field | Type | Description |
|---|---|---|---|
| `ieee80211p.PreambleSensitivityDbm` | `sensitivity11p_dBm` | `double` | SINR threshold to decoded the preamble of 11p |
| `ieee80211p.LtePhysicalLayerEnabled` | `pWithLTEPHY` | `bool` | Boolean to simulate LTE PHY in 11p |
| `ieee80211p.Mcs` | `MCS_11p` | `integer` | TX Mode |
| `ieee80211p.LtePhysicalLayerMcs` | `MCS_pWithLTEphy` | `integer` | Modulation and coding scheme |
| `ieee80211p.RelativeInterferenceLevelModelEnabled` | `rilModel11p` | `bool` | Boolean to use the relative interference level (RIL) model in 11p |
| `ieee80211p.ContentionWindow` | `CW` | `integer` | Contention Window |
| `ieee80211p.AifsSlotCount` | `AifsN` | `integer` | Arbitration inter-frame space |
| `ieee80211p.CcaThresholdWithoutDecodedPreambleDbm` | `CCAthr11p_notsync` | `double` | CCA threshold to set busy if not decodable [dBm] |
| `ieee80211p.CcaThresholdWithDecodedPreambleDbm` | `CCAthr11p_sync` | `double` | CCA threshold to set busy if decodable [dBm] |
| `ieee80211p.LosPacketDecodeSinrThresholdDb` | `sinrThreshold11p_LOS` | `double` | SINR threshold for error assessment [dB] |

### `itsG5`

ETSI ITS-G5 profile behavior built on the IEEE 802.11 access layer.

| V7 field | V6 field | Type | Description |
|---|---|---|---|
| `itsG5.Repetition.Mode` | `retransType` | `integer` | Retransmission type, 0: static, 1: deterministic, 2: probabilistic |
| `itsG5.Repetition.MaximumTransmissionCount` | `ITSNumberOfReplicasMax` | `integer` | Number of retransmissions of ITS-G5 |
| `itsG5.Repetition.BackoffMicroseconds` | `ITSRetransBackoffInterval` | `integer` | ITS-G5 retransmission backoff interval [us] |
| `itsG5.Repetition.LowCbrThreshold` | `ITSReplicasThreshold1` | `double` | CBR threshold 1 for ITS-G5 retransmission |
| `itsG5.Repetition.MediumCbrThreshold` | `ITSReplicasThreshold2` | `double` | CBR threshold 2 for ITS-G5 retransmission |
| `itsG5.Repetition.HighCbrThreshold` | `ITSReplicasThreshold3` | `double` | CBR threshold 3 for ITS-G5 retransmission |

### `lteV2x`

LTE-V2X-specific sidelink physical-layer settings.

| V7 field | V6 field | Type | Description |
|---|---|---|---|
| `lteV2x.Mcs` | `MCS_LTE` | `integer` | Modulation and coding scheme |
| `lteV2x.AdjacentPscchAndPsschEnabled` | `ifAdjacent` | `bool` | If using adjacent PSCCH and PSSCH |

### `nrV2x`

NR-V2X-specific sidelink physical-layer settings.

| V7 field | V6 field | Type | Description |
|---|---|---|---|
| `nrV2x.SubcarrierSpacingKilohertz` | `SCS_NR` | `integer` | 5G SCS |
| `nrV2x.DmrsResourceElementCountPerSlot` | `nDMRS_NR` | `integer` | Number of DMRS per slot |
| `nrV2x.Mcs` | `MCS_NR` | `integer` | MCS for NR |
| `nrV2x.SciSymbolCount` | `SCIsymbols` | `integer` | Number of SCI symbols per slot |
| `nrV2x.SciResourceBlockCount` | `nRB_SCI` | `integer` | Number of RBs dedicated to the SCI-1 |

### `sidelink`

Behavior shared by LTE-V2X and NR-V2X direct PC5 communication.

| V7 field | V6 field | Type | Description |
|---|---|---|---|
| `sidelink.CongestionControl.ChannelOccupancyLimitScale` | `cv2xCbrFactor` | `double` | Factor for CV2X DCC thresholds |
| `sidelink.DuplexMode` | `duplexCV2X` | `string` | Duplexing type |
| `sidelink.FullDuplex.ResidualSelfInterferenceDb` | `Ksi_dB` | `double` | Self-interference cancellation coefficient (dB) |
| `sidelink.InBandEmissionEnabled` | `haveIBE` | `bool` | Simulator considers the In-Band Emission |
| `sidelink.Harq.MaximumTransmissionCount` | `cv2xNumberOfReplicasMax` | `integer` | Number of transmissions (HARQ) |
| `sidelink.LosPacketDecodeSinrThresholdDb` | `sinrThresholdCV2X_LOS` | `double` | SINR threshold for error assessment [dB] |
| `sidelink.SciDecodeSinrThresholdDb` | `minSCIsinr` | `double` | Minimum SINR for a SCI to be correctly decoded, in dB |

### `resourceAllocation`

Controlled and autonomous sidelink resource-selection algorithms.

| V7 field | V6 field | Type | Description |
|---|---|---|---|
| `resourceAllocation.FullDuplex.SelfInterferenceThresholdMultiplier` | `PDelta` | `double` | Multiplicative SelfI factor to set FD reselection threshold |
| `resourceAllocation.Algorithm` | `BRAlgorithm` | `integer` | Assignment algorithm |
| `resourceAllocation.Controlled.PositionError95PercentileMeters` | `posError95` | `double` | LTE positioning error - 95th percentile (only controlled) (m) |
| `resourceAllocation.Controlled.PositionUpdateIntervalSeconds` | `Tupdate` | `double` | Time interval between position updates at the eNodeBs (s) |
| `resourceAllocation.Controlled.ReuseMarginMeters` | `Mreuse` | `integer` | Reuse margin (m) |
| `resourceAllocation.Controlled.ReassignmentIntervalSeconds` | `Treassign` | `double` | Interval of scheduled reassignment (BRAlgorithm 2,7,9,10) (s) |
| `resourceAllocation.Controlled.KnownShadowingEnabled` | `knownShadowing` | `bool` | if shadowing is estimated at the eNB side |
| `resourceAllocation.Autonomous.ReevaluationEnabled` | `resourceReEvaluation` | `bool` | Activates the resource re-evaluation in NR-V2X |
| `resourceAllocation.Autonomous.ReevaluateAfterSkippedTransmissionEnabled` | `reEvalAfterEmptyResource` | `bool` | Activates the resource re-evaluation in NR-V2X after empty transmission |
| `resourceAllocation.Autonomous.ReselectEveryPacketEnabled` | `dynamicScheduling` | `bool` | Probability to keep the previously selected BR |
| `resourceAllocation.Autonomous.KeepResourceProbability` | `probResKeep` | `double` | Probability to keep the previously selected BR |
| `resourceAllocation.Autonomous.MinimumCandidateFraction` | `ratioSelectedAutonomousMode` | `double` | Minimum fraction of resources surviving RSRP filtering |
| `resourceAllocation.Autonomous.L2CandidateFraction` | `ratioSelectedL2` | `double` | Fraction of possible resources retained by L2 ranking |
| `resourceAllocation.Autonomous.L2RankingEnabled` | `L2active` | `bool` | Activate or De-activate L2 in mode2/mode4 |
| `resourceAllocation.Autonomous.AverageSensingEnabled` | `averageSensingActive` | `bool` | Activate or De-activate the average sensing mode2/mode4 |
| `resourceAllocation.Autonomous.SensingWindowSeconds` | `TsensingPeriod` | `double` | Duration of the sensing period, in seconds |
| `resourceAllocation.Autonomous.ReselectionCounterMinimum` | `minRandValueMode4` | `integer` | Minimum duration keeping the same allocation |
| `resourceAllocation.Autonomous.ReselectionCounterMaximum` | `maxRandValueMode4` | `integer` | Maximum duration keeping the same allocation |
| `resourceAllocation.Autonomous.SensingThresholdDbm` | `powerThresholdAutonomous` | `double` | Minimum power threshold to consider a BR as occupied in Mode 4, in dBm |
| `resourceAllocation.Autonomous.SelectionWindowStartMilliseconds` | `T1autonomousMode` | `integer` | Minimum time for the next allocation in Autonomous Mode |
| `resourceAllocation.Autonomous.SelectionWindowEndMilliseconds` | `T2autonomousMode` | `integer` | Maximum time for the next allocation in autonomous mode |
| `resourceAllocation.Asynchrony.Mode` | `asynMode` | `integer` | Enables/Desable Asynchronous transmitters |
| `resourceAllocation.Asynchrony.VehicleFraction` | `percAsynUser` | `double` | Percentage of asynchronous users |
| `resourceAllocation.FullDuplex.Algorithm` | `FDalgorithm` | `integer` | Enables FD algorithm |
| `resourceAllocation.FullDuplex.DynamicThresholdMode` | `dynamicPDelta` | `integer` | Enables dynamic setting of PDelta |

### `output`

Output directory and optional metrics or reports.

| V7 field | V6 field | Type | Description |
|---|---|---|---|
| `output.Directory` | `outputFolder` | `string` | Folder for the output files |
| `output.NeighborCount.Enabled` | `printNeighbors` | `bool` | Activate the print to file of the number of neighbors |
| `output.VehicleKinematics.Enabled` | — | `bool` | Record long-form vehicle kinematics (`X`, `Y`, `vX`, `vY`, `aX`, and `aY`) |
| `output.UpdateDelay.Enabled` | `printUpdateDelay` | `bool` | Activate the print to file of the update delay between received beacons |
| `output.WirelessBlindSpot.Enabled` | `printWirelessBlindSpotProb` | `bool` | Activate the print to file of the wireless blind spot probability |
| `output.WirelessBlindSpot.MaximumDelaySeconds` | `delayWBSmax` | `double` | Maximum recordable delay for wireless blind spot probability (s) |
| `output.WirelessBlindSpot.BinWidthSeconds` | `delayWBSresolution` | `double` | Resolution of wireless blind spot probability (s) |
| `output.PacketDelay.Enabled` | `printPacketDelay` | `bool` | Activate the print to file of the packet delay between received beacons |
| `output.DataAge.Enabled` | `printDataAge` | `bool` | Activate the print to file of data age of beacons |
| `output.DelayMetrics.BinWidthSeconds` | `delayResolution` | `double` | Delay resolution (s) |
| `output.PacketReceptionRatio.Enabled` | `printPacketReceptionRatio` | `bool` | Activate the print to file of detailed PRR up to the maximum awareness range |
| `output.PacketReceptionRatio.DistanceBinWidthMeters` | `prrResolution` | `integer` | Step of the distance for the calculation of the pdr [m] |
| `output.ChannelBusyRatio.Enabled` | `printCBR` | `bool` | Activate the print to file of the channel busy ratio |
| `output.CoexistenceTechnologyShare.Enabled` | `coex_printTechPercentage` | `bool` | Coex: print technology percentage to file |

When channel-busy-ratio output is enabled in a coexistence mode, the
simulator also writes
`coex_cv2xOnly_CBRstatistic_<simulation-id>_<LTE-or-5G>.csv` when
CV2X-only CBR samples are available. This separate CSV contains two
columns: the CV2X-only CBR sample and its cumulative ECDF probability.
It does not add a column to the standard CBR CSV files and is not
produced in single-technology modes.

### `coexistence`

Joint IEEE 802.11p/ITS-G5 and cellular-sidelink coexistence methods.

| V7 field | V6 field | Type | Description |
|---|---|---|---|
| `coexistence.VehiclePattern.SidelinkVehicleCount` | `numVehiclesLTE` | `integer` | How many consecutive vehicles use LTE-V2X |
| `coexistence.VehiclePattern.ItsG5VehicleCount` | `numVehicles11p` | `integer` | How many consecutive vehicles use IEEE 802.11p |
| `coexistence.Method` | `coexMethod` | `string` | Select the coexistence method. "0" means standard solution |
| `coexistence.Superframe.DurationSeconds` | `coex_superFlength` | `double` | Coexistence, superframe length [s] |
| `coexistence.Superframe.SlotAllocationMode` | `coex_slotManagement` | `string` | coex: static or dynamic management of slots |
| `coexistence.Superframe.SidelinkPortionEndSeconds` | `coex_endOfLTE` | `double` | Coex: end of the LTE portion within the superframe [s] (-1 is automatic set) |
| `coexistence.MethodA.GuardIntervalSeconds` | `coexA_guardTime` | `double` | Coex A: guard time between portions [s] |
| `coexistence.MethodA.EnhancementVariant` | `coexA_improvements` | `integer` | Coex A: improvements outside ETSI doc |
| `coexistence.MethodA.SynchronizationErrorSeconds` | `coexA_desynchError` | `double` | Coex A: error in ITS-G5 synch |
| `coexistence.MethodA.LegacyItsG5NodesEnabled` | `coexA_withLegacyITSG5` | `bool` | Assume ITS-G5 legacy nodes |
| `coexistence.MethodA.ItsG5PerceivedSidelinkEndSeconds` | `coexA_endOfLteKnownBy11p` | `double` | Coex A: end of LTE slot by ITS-G5 (-1 is coex_endOfLTE) |
| `coexistence.MethodB.EnergySignalLeadTimeSeconds` | `coexB_timeBeforeLTEstarts` | `double` | Coex B: beginning of energy symbol (Type 1) before LTE part starts [s] |
| `coexistence.MethodB.AllNodesTransmitInEmptySubframes` | `coexB_allToTransmitInEmptySF` | `bool` | Coex B: if all nodes should transmit ES in empty SF or only selected |
| `coexistence.MethodC.TimeGapVariant` | `coexC_timegapVariant` | `integer` | Coex C: variant of the time gap before LTE slot |
| `coexistence.MethodC.DetectAndCancelItsG5Enabled` | `coexC_11pDetection` | `bool` | Coex C: variant where 11p is detected and its interference removed |
| `coexistence.MethodC.ModifiedContentionWindowEnabled` | `coexCmodifiedCW` | `bool` | Coex C: variant where 11p has a modified CW calculation |
| `coexistence.MethodC.MultipleSubframeIndicationEnabled` | `coexC_moreThanOneSubframe` | `bool` | Coex C: variant where more than 1 subframe is indicated |
| `coexistence.MethodF.GuardIntervalEnabled` | `coexF_guardTime` | `bool` | Coex F: guard interval added in ITS-G5 before superframe |
| `coexistence.Cbr.SidelinkVariant` | `coex_cbrLteVariant` | `integer` | Coex: variant of the cbr-lte calculation |
| `coexistence.Cbr.TotalVariant` | `coex_cbrTotVariant` | `integer` | Coex: variant of the cbr-tot calculation |

### `infrastructure`

Roadside-unit configuration.

| V7 field | V6 field | Type | Description |
|---|---|---|---|
| `infrastructure.Rsu.ConfigurationFile` | `RSUcfg` | `string` | Config file for RSUs - Null if no RSUs |

## Fields removed from V6

These V6 fields are not aliases in V7. They represented disabled, unreachable,
or absent implementations and now produce an unknown-parameter error when used
as MATLAB arguments. Stale occurrences were removed from shipped configurations.

| Removed V6 field | Why it was removed |
|---|---|
| `neighborsSelection` | Enabling it immediately stopped the simulation; the neighbor-selection implementation was commented out. |
| `variableBeaconSize` | Variable packet sizing was explicitly disabled and its selection logic was commented out. |
| `beaconSizeSmallBytes` | Depended on the removed variable-packet-size mode. |
| `NbeaconsSmall` | Depended on the removed variable-packet-size mode. |
| `enableUpdateDelayHD` | Its only calculation and decision path were commented out. |
| `printPowerControl` | Enabling the report immediately stopped the simulation; the calculation was disabled. |
| `powerResolution` | Only configured the removed power-control report. |
| `printHiddenNodeProb` | Enabling the report immediately stopped the simulation; its KPI calculation was disabled. |
| `Pth_dBm` | Only configured the removed hidden-node report. |
| `Ksic` | The successive-interference-cancellation implementation was absent. |
| `nsic` | Only described iterations for the absent SIC implementation. |
| `forwardSIC` | Had no active reader. |
| `nChannels` | Values above one invoked missing multi-channel initialization; V7 fixes the internal channel count at one. |

The cleanup also removed already-commented declarations for `Mvicinity`,
`NsensingPeriod`, `printDistanceDetails`, `mco_nVehInterf`,
`mco_printInterfStatistic`, `winnerModel`, `mco_interfERP`,
`mco_resPowerFromAdjacent`, `mco_interfNeglectedToMainChannel`, and
`coexB_portionOfPower`. These were not active V6 inputs and have no V7 aliases.

## Layer terminology

`application.Cam` describes generation of CAM messages and is independent of
the radio used to carry them. `ieee80211p` contains generic 802.11p PHY/MAC
settings. `itsG5` is reserved for ETSI ITS-G5 profile behavior built on that
access technology. `sidelink` means the common LTE-V2X/NR-V2X PC5 direct link;
technology-specific settings remain under `lteV2x` or `nrV2x`.
