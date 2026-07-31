# FWLabsV2XSim

**FWLabsV2XSim** is a dynamic MATLAB simulator for resource-allocation
research in sidelink C-V2X, NR-V2X, and IEEE 802.11p/ITS-G5 networks.

## Name and lineage

This project is a hard-fork rewrite of [WiLabV2Xsim](https://github.com/V2Xgithub/WiLabV2Xsim/), hence the rename.
It is not API compatible with the ancestor, but it tries to maintain feature parity and notably the ability to reassert the same scientific conclusions of some key papers that previously used WiLabV2Xsim. 

The rewrite prioritises runtime code safety, robustness, and modern software design patterns for maintainability.

The version number is bumped to V7 to differentiate it from WiLabV2XSim.

The project began as
[LTEV2VSim](https://github.com/alessandrobazzi/LTEV2Vsim). When WiLab/CNIT
became significantly involved and the simulator was promoted from v5 to v6,
it was renamed **WiLabV2XSim**. Version 6.1 introduced 5G-V2X, including NR
and its numerologies, while generalizing LTE- and NR-shared parameters as
C-V2X concepts.

Version 7 is named **FWLabsV2XSim** to recognize the significant involvement
of the **Future Communications Connectivity Lab at the Singapore University
of Technology and Design**. The leading `F` is the first letter of that lab's
organisation name, prepended to the `W` inherited from WiLab.

This naming convention preserves the project's institutional lineage. When
another laboratory becomes significantly involved in a future major version,
its contributors may prepend their organisation's initial to the existing
name as part of that version upgrade.

The simulator is shared under the GNU GPLv3. FWLabsV2XSim v7 is developed
with contributions from the Future Communications Connectivity Lab at the
Singapore University of Technology and Design, WiLab/CNIT, the University of
Bologna, and CNR.

Version 7 uses a strict, namespaced TOML 1.0 configuration schema. See the
[V7 configuration reference](docs/toml-configuration-v7.md) for the
namespace hierarchy, defaults, tagged variants, and validation rules. Legacy
`.cfg` files and V6 parameter aliases are intentionally unsupported.

Open `FWLabsV2XSim.prj` before using V7. The MATLAB Project owns source-path
configuration, and simulations are launched through the namespaced,
path-preserving entrypoint:

```matlab
template = v2xsim.config.load("experiment.toml");
patch = v2xsim.config.patch(struct( ...
    Simulation=struct(DurationSeconds=10)));
configuration = template.resolve(Patch=patch);
result = v2xsim.runSimulation( ...
    configuration, ...
    OutputDirectory="results/seed-1", ...
    RunLabel="seed-1");
```

The [progressive V7 examples](examples/v7/README.md) provide short runnable
scripts and canonical configuration files for a first simulation,
component-owned random streams, named resource allocators, positioning-error
chains, hook-backed outputs, isolated multi-run sweeps, centralized NR Mode 1
allocation, the three 3GPP freeway traffic presets, and all four public
mobility scenarios, plus NR Mode 2 and its derived beacon-resource grid. The
[V7 researcher wiki](https://github.com/caspycat/FWLabsV2XSim/wiki)
provides the task-oriented tutorials and data-analysis reference.

V7 also exposes cellular-sidelink beacon-resource selection through named,
slice-scoped allocator contracts. See the
[BR resource-allocation architecture](docs/br-resource-allocation.md) for the
centralized and autonomous interfaces, available algorithms, coexistence
boundary, and named V7 selectors.

# Dependencies

To run and develop the simulator in the MATLAB IDE, the following MathWorks products are required:
- MATLAB R2026a
- Statistics and Machine Learning Toolbox
- Signal Processing Toolbox
- Parallel Computing Toolbox
- (for testing) MATLAB Test
- (for compiling binaries) MATLAB Compiler

The following external MATLAB libraries are added as git submodules and project references:
- [matlab-toml](https://github.com/g-s-k/matlab-toml)
- [matgeom](https://github.com/mattools/matGeom)

The [V7 correctness and integration testing
guide](docs/testing-v7.md) describes the behavioral contracts, full ordinary
test gate, coverage report, and process-worker isolation rules.

The main reference for the WiLabV2XSim v6 simulator is

***V. Todisco, S. Bartoletti, C. Campolo, A. Molinaro, A. O. Berthet, andA.  Bazzi,  “Performance  analysis  of  sidelink  5G-V2X  mode  2  through an  open-source  simulator,” IEEE Access,  2021***, open access at https://ieeexplore.ieee.org/abstract/document/9579000 

The main references for the previous versions of the simulator are 

G. Cecchini, A. Bazzi, B. M. Masini, A. Zanella, “LTEV2Vsim: An LTE-V2V Simulator for the Investigation of Resource Allocation for Cooperative Awareness”, 5th IEEE International Conference on Models and Technologies for Intelligent Transportation Systems (MT-ITS 2017), Naples (Italy), 26-28 June 2017. (Results obtained with version 1.0)

A. Bazzi, G. Cecchini, M. Menarini, B. M. Masini, A. Zanella, “Survey and Perspectives of Vehicular Wi-Fi Versus Sidelink Cellular-V2X in the 5G Era,” invited paper in Future Internet, 29 May 2019, 11(6), 122. DOI: 10.3390/fi11060122 (Results obtained with version 3.5)

*****
Some references to papers where WiLabV2XSim v6 was used:

A. Bazzi, C. Campolo, V. Todisco, S. Bartoletti, N. De Carli, A. Molinaro, A.O. Berthet, R.A. Stirling-Gallacher, “Towards 6G-V2X Sidelink: Non-Orthogonal Multiple Access in the Autonomous Mode”, IEEE Vehicular Technology Magazine, vol. 18, n. 2, pp. 50-59, 2023.

V. Todisco, C. Campolo, A. Molinaro, A. Berthet, R.A. Stirling-Gallacher, A. Bazzi, “On the Performance of SIC-based NOMA in the C-V2X Sidelink Autonomous Mode”, IEEE CSCN 2023.

V. Todisco, C. Campolo, A. Molinaro, A. Berthet, R.A. Stirling-Gallacher, A. Bazzi, “Joint use of Self and Successive Interference Cancellation in V2X Sidelink with Autonomous Resource Allocation”, IEEE VTC-Spring 2023.

C. Campolo, A. Bazzi, V. Todisco, S. Bartoletti, N. De Carli, A. Molinaro, A. Berthet, R.A. Stirling-Gallacher, “Enhancing the 5G-V2X Sidelink Autonomous Mode through Full-Duplex capabilities”, IEEE VTC-Spring 2022.

C. Campolo, V. Todisco, S. Bartoletti, A. Molinaro, A. Berthet, A. Bazzi, “Improving Resource Allocation for beyond 5G V2X Sidelink Connectivity”, ASILOMAR Conference on Signals, Systems and Computers 2021

A. Bazzi, C. Campolo, A. Molinaro, A. Berthet, B. Masini, A. Zanella, “On Wireless Blind Spots in C-V2X Sidelink”. IEEE Transactions on Vehicular Technology, vol. 69, n. 8, pp. 9239-9243, 2020.
*****

*****
List of main current contributors (those to whom you can ask)

Alessandro Bazzi (alessandro.bazzi@unibo.it)

Vittorio Todisco (vittorio.todisco@unibo.it, vittorio.todisco@ieiit.cnr.it)

Wu Zhuofei, also called Felix (wuzhuofei@aqnu.edu.cn, wzfhrb.cn@gmail.com)
*****

*****
Also contributing or contributed, in alphabetic order (if you feel you should be in the list, just let us know...we apologize, we are sure we are missing someone)

Stefania Bartoletti

Claudia Campolo

Giammarco Cecchini

Michele Menarini

Francesco Romeo 
*****
