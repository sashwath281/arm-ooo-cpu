# LEGv8 Pipelined CPU

A 5-stage pipelined LEGv8 processor implemented from scratch in SystemVerilog. Supports the LEGv8 base ISA with classical in-order pipelining, hazard handling via forwarding and stalls, and a Harvard-style memory model.

LEGv8 is the 64-bit ARMv8 educational subset defined in Patterson & Hennessy, *Computer Organization and Design: ARM Edition*.

## What's Implemented

- **5-stage pipeline:** Fetch · Decode · Execute · Memory · Writeback
- **Datapath:** 64-bit ALU with overflow/zero detect, 32 × 64-bit register file, sign-extension unit, shifter, branch logic
- **Control:** Main control unit, ALU control, condition evaluation for `B.cond` branches
- **Hazard handling:** EX/MEM and MEM/WB forwarding units, load-use stall detection
- **Memory:** Separate instruction and data memories (Harvard-style)
- **Tested with:** Custom LEGv8 assembly benchmarks in `sw/tests/`

## Architecture

```
IF  →  ID  →  EX  →  MEM  →  WB
```

- **IF** — Program counter + instruction memory fetch
- **ID** — Instruction decode, register file read, sign-extension, control signal generation
- **EX** — ALU operation, branch target calculation, condition evaluation
- **MEM** — Data memory access for loads and stores
- **WB** — Result writeback to register file

Forwarding paths from the EX/MEM and MEM/WB pipeline registers resolve most data hazards. Load-use hazards trigger a single-cycle pipeline stall.

## Repository Layout

```
rtl/
├── core/      Pipeline stages, control, datapath
├── common/    Reusable submodules (muxes, adders, decoders, flops, registers)
└── memory/    Instruction and data memory models
tb/            Testbenches
sim/           Simulation scripts
sw/            LEGv8 assembly test programs
docs/          Diagrams, architecture notes
```

## Simulating

Built and tested in Questa on the UW Linux servers:

```bash
ssh <netid>@<uw-linux-host>
cd arm-ooo-cpu/sim/scripts
vsim -do runlab.do
```

## Toolchain

- **HDL:** SystemVerilog (IEEE 1800-2017)
- **Simulator:** Questa
- **Waveform viewer:** Questa
- **Target ISA:** LEGv8 (ARMv8-A subset)

## References

- Patterson & Hennessy, *Computer Organization and Design: ARM Edition*
- ARM Architecture Reference Manual, ARMv8-A

## Author

Sashwath Narayanan — ECE, University of Washington