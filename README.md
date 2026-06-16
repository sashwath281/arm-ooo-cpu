# arm-ooo-cpu

An out-of-order LEGv8 CPU built from scratch in SystemVerilog, with L1 caches, gshare branch prediction, an AXI-based SoC on the DE1-SoC Cyclone V FPGA, and a UVM verification environment with SymbiYosys formal proofs.

LEGv8 is the 64-bit ARMv8 educational subset defined in Patterson & Hennessy, *Computer Organization and Design: ARM Edition*.

## Project Goal

Start from a working in-order 5-stage pipelined LEGv8 core (`v0-baseline`) and extend it through a 13-week sprint into:

- A full out-of-order LEGv8 core with L1 I/D caches and gshare branch prediction
- An AXI-based SoC bridging the soft LEGv8 core to the hard Cortex-A9 HPS on the DE1-SoC via the Lightweight AXI bridge
- A UVM verification environment with constrained-random stimulus, functional coverage, SVA, and SymbiYosys formal proofs

## 13-Week Milestone List

| Week | Dates              | Milestone                                                            |
|------|--------------------|----------------------------------------------------------------------|
| 1    | Jun 16 – Jun 22    | I-cache RTL + integration into fetch; SV OOP recap                   |
| 2    | Jun 23 – Jun 29    | D-cache RTL + memory stage integration; SV interfaces                |
| 3    | Jun 30 – Jul 6     | Branch predictor (gshare) + BTB integrated into fetch                |
| 4    | Jul 7  – Jul 13    | Register rename + ROB groundwork                                     |
| 5    | Jul 14 – Jul 20    | Issue queue / reservation stations + wakeup-select logic             |
| 6    | Jul 21 – Jul 27    | OoO execute + commit path; precise exception support                 |
| 7    | Jul 28 – Aug 3     | Full OoO core integration, debug, IPC characterization               |
| 8    | Aug 4  – Aug 10    | AXI4 / AXI4-Lite study + bus fabric                                  |
| 9    | Aug 11 – Aug 17    | SoC peripheral integration (UART, GPIO, memory controller)           |
| 10   | Aug 18 – Aug 24    | DE1-SoC bring-up, HPS-to-FPGA Lightweight AXI bridge                 |
| 11   | Aug 25 – Aug 31    | On-hardware SoC validation, software stack                           |
| 12   | Sep 1  – Sep 7     | UVM environment (agent, driver, monitor, scoreboard, coverage)       |
| 13   | Sep 8  – Sep 14    | SVA properties + SymbiYosys formal proofs; golden-reference cosim    |

## Repository Layout

```
rtl/        SystemVerilog design sources
tb/         Testbenches (unit + integration)
sim/        Simulation scripts, Makefiles, waveform configs
sw/         LEGv8 assembly test programs and toolchain notes
docs/       Architecture specs, block diagrams, weekly logs
scripts/    Utility scripts
```

## Toolchain

- **HDL:** SystemVerilog (IEEE 1800-2017)
- **Simulator:** Questa (UW Linux servers via SSH) / Verilator (local, open source)
- **Waveform viewer:** GTKWave, Questa
- **Synthesis / FPGA:** Intel Quartus Prime, DE1-SoC (Cyclone V)
- **Verification:** UVM 1.2, SymbiYosys (formal)
- **Golden reference:** TBD (custom LEGv8 ISS or QEMU aarch64 with real-AArch64 test programs)
- **Cross-compile:** `aarch64-none-elf-gcc` for AArch64 test programs

## Build & Simulate

### Prerequisites
```bash
sudo apt install verilator gtkwave make
sudo apt install gcc-aarch64-linux-gnu     # for AArch64 cross-compile
pip install sby                            # optional, for SymbiYosys formal
```

### Simulate on UW Linux servers (Questa)
```bash
ssh <netid>@<uw-linux-host>
cd arm-ooo-cpu/sim/scripts
vsim -do runlab.do
```

### Simulate a single module (Verilator, local)
```bash
cd sim
make MODULE=icache_top
make wave    # opens GTKWave on the resulting .vcd
```

## Tags

- `v0-baseline` — in-order LEGv8 5-stage pipelined CPU before the OoO sprint
- *(further tags added as milestones land)*

## References

- Patterson & Hennessy, *Computer Organization and Design: ARM Edition*
- Hennessy & Patterson, *Computer Architecture: A Quantitative Approach* (6e)
- Shen & Lipasti, *Modern Processor Design*
- Spear, *SystemVerilog for Verification* (3e)
- ARM Architecture Reference Manual, ARMv8-A

## Author

Sashwath Narayanan — ECE, University of Washington, Class of 2028