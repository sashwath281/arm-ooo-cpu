# arm-ooo-cpu

Out-of-order LEGv8 processor with split L1 caches and gshare branch prediction. SystemVerilog RTL targeting FPGA prototyping and UVM-driven verification.

## ISA

The core implements LEGv8 — the 64-bit ARMv8 educational subset defined in Patterson & Hennessy, *Computer Organization and Design: ARM Edition*. Supported instruction classes:

- **Arithmetic / logical**: ADD, ADDI, ADDS, ADDIS, SUB, SUBI, SUBS, SUBIS, AND, ANDI, ANDS, ORR, ORRI, EOR, EORI
- **Memory**: LDUR, STUR
- **Control transfer**: B, BL, BR, CBZ, B.cond
- **Other**: LSL, LSR, MOVZ, MOVK

## Microarchitecture

### Front end
- 64-bit byte-addressed PC, 32-bit instruction fetch
- gshare branch predictor: global history register XORed with PC indexing into a table of 2-bit saturating counters
- Branch target buffer for direct branch targets
- Speculative fetch with single-cycle misprediction recovery

### Back end
- Out-of-order issue with register renaming
- Reorder buffer for in-order commit
- Issue queue feeding the integer ALU and memory pipeline
- Load/store queue with store-to-load forwarding
- In-order commit preserving precise architectural state

### Memory hierarchy
- Split L1 instruction and data caches
- Write-back, write-allocate data cache

### Hazard handling
- Full forwarding from EX/MEM and MEM/WB to EX
- Write-back-to-ID forwarding for same-cycle register file reads
- Hazard detection unit with load-use stall and branch flush
- No architectural delay slots — all hazards resolved in hardware

## Pipeline

The repository contains two implementations sharing a common module library:

- **In-order baseline** (`v0-baseline`, `v1-hazard-detection`): classic 5-stage IF / ID / EX / MEM / WB pipeline with forwarding and hazard detection
- **Out-of-order core** (`v2-ooo` onward): fetch / decode-rename / dispatch / issue / execute / memory / writeback / commit



## Repository layout

```
rtl/
  core/
    PipelinedCPU.sv          top-level integration
    Control.sv               main control decoder
    BranchLogic.sv           branch resolution in ID
    ForwardingUnit.sv        EX/MEM and MEM/WB forwarding
    WBForwardUnit.sv         write-back to ID forwarding
    HazardDetectionUnit.sv   load-use stall and branch flush
    ALUControl.sv, alu.sv    integer execution
    regfile.sv               architectural register file
    signextend.sv, shiftLeft.sv
    PC.sv, instructmem.sv, datamem.sv
  common/
    mux2to1, mux4to1, mux5_2to1, mux32_2to1, mux64_2to1, mux64_4to1
    adder64, full_adder, register1, register5, register32, register64
    decoder2to4, decoder3to8, decoder5to32, D_FF
sw/
  tests/
    *.arm                    LEGv8 test programs in ASCII binary format
```

## Verification

- Directed assembly tests for per-instruction correctness
- Microbenchmarks isolating each hazard mechanism: load-use stall, branch flush, combined load-into-branch
- Reference comparison against a LEGv8 instruction set simulator
- SystemVerilog assertions covering pipeline invariants and protocol compliance
- UVM verification environment (separate repository) with constrained-random stimulus, scoreboard, and functional coverage
- Formal verification of control-path properties with SymbiYosys

## Build and simulation

Targets Intel Quartus Prime for synthesis on the Terasic DE1-SoC (Cyclone V). Behavioral simulation via ModelSim / Questa.

```
vlib work
vlog rtl/core/*.sv rtl/common/*.sv
vsim -c -do "run -all" PipelinedCPU_tb
```

## References

- Patterson and Hennessy, *Computer Organization and Design: ARM Edition*
- Shen and Lipasti, *Modern Processor Design*
- Hennessy and Patterson, *Computer Architecture: A Quantitative Approach*

## Author

Sashwath Narayanan — University of Washington, ECE