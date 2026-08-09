# Out-of-Order LEGv8 CPU

A single-issue, out-of-order processor implementing the LEGv8 instruction set (ARMv8 subset from Patterson & Hennessy's *Computer Organization and Design: ARM Edition*). Built in SystemVerilog, simulated with ModelSim.

## ISA

LEGv8 — the 64-bit ARMv8 educational subset defined in Patterson & Hennessy, *Computer Organization and Design: ARM Edition*. Supported instruction classes:

- **Arithmetic / logical**: ADD, ADDI, ADDS, SUB, SUBI, SUBS, AND, ANDI, ORR, ORRI, EOR
- **Memory**: LDUR, STUR
- **Control transfer**: B, BR, CBZ, B.cond
- **Other**: LSL, LSR

## Microarchitecture

### Front end
- 64-bit byte-addressed PC, 32-bit instruction fetch
- 4KB direct-mapped I-Cache with 32-byte blocks (128 sets, 10-cycle memory backend)
- gshare branch predictor: 256-entry PHT indexed by PC XOR 8-bit BHR
- 64-entry Branch Target Buffer
- Speculative fetch with single-cycle registered mispredict recovery

### Rename
- 32 to 64 register renaming: 32 architectural, 64 physical registers
- Register Alias Table (RAT) with 32 checkpoint snapshots
- 32-entry Free List (FIFO) tracking available physical registers
- 64-bit Busy Table tracking pending physical register writes

### Dispatch and Track
- Atomic allocation into 32-entry ROB, 16-entry Issue Queue, and 16-entry Store/Load Queues
- Backpressure to fetch if any structure is full
- Per-branch RAT checkpoint saved at dispatch

### Issue - Execute - CDB
- Priority-encoder select of oldest ready IQ entry
- Single integer ALU with immediate operand mux
- CDB broadcast: writes PRF, wakes dependent IQ entries, completes ROB entry — all in one cycle

### Memory
- 16-entry Store Queue and 16-entry Load Queue
- ROB-index-based age tracking for store-to-load forwarding
- Loads check SQ first before D-Cache not implemented yet. 
### Recovery and Commit
- Single-cycle registered flush on mispredict
- RAT restored from checkpoint keyed by ROB slot ID
- ROB, IQ, SQ, LQ selectively invalidate entries younger than mispredicted branch
- In-order retirement returning old physical register to free list

## Verification Results

Measured on directed test programs:

| Metric | Value |
|--------|-------|
| I-Cache hit rate | 97% (485 hits / 499 accesses) |
| Branch mispredicts | 0 (on tested arithmetic sequences) |
| Committed instructions | Verified across arithmetic and register-renaming tests |

**Verified:**
- Register renaming with complex dependency chains (multiple writes to same architectural register)
- CDB broadcast wakeup within same cycle
- Precise in-order commit with old-register return to free list
- Age-tracked store-to-load forwarding via ROB indices
- Single-cycle branch prediction path
- X31 (XZR) protection from renaming

## Known Limitations (v1.0)

- **D-Cache not implemented**: The load queue currently returns a placeholder value since the D-Cache is not yet built. Adding it requires a write-back or write-through D-Cache module and an arbiter between the LQ read path and SQ drain path. Currently the OoO engine can be exercised for arithmetic, register renaming, and control flow, but not for real memory operations.

- **NZCV flag renaming not implemented**: B.LT depends on flags from a preceding ADDS/SUBS. The current implementation uses the branch instruction's own ALU output rather than renamed prior flags. Adding NZCV as a separately-renamed architectural resource would fix this.

- **Complex branch recovery edge case**: Some CBZ/B sequences trigger a bug in the recovery unit's redirect PC path. Root cause isolated but not resolved.

- **BL (Branch-and-Link) disabled**: Return address (PC+4) not wired through rename pipeline. Adding BL requires plumbing the link register through the rename stage.

## Roadmap (v2.0)

The following work is planned over the coming weeks:

**Immediate:**
- Fix the branch recovery redirect PC bug
- Integrate D-Cache with arbiter mux for LQ read and SQ drain paths
- Add NZCV condition flags as a renamed architectural resource

**UVM verification environment:**
- Build a proper UVM testbench with agents, sequences, and scoreboard
- Add SystemVerilog Assertions covering pipeline invariants
- Implement functional coverage for OoO scheduling scenarios
- Automated regression suite

**FPGA synthesis:**
- Vivado synthesis targeting Xilinx Artix-7
- Characterize maximum clock frequency
- Identify and analyze critical path (expected: RAT read - PRF address decode - ALU output)

**Extensions:**
- 2-issue OoO with dual CDBs
- L2 shared cache with real DRAM model
- Extend to full AArch64 ISA

## Building / Running


## References

- Patterson and Hennessy, *Computer Organization and Design: ARM Edition*
- Shen and Lipasti, *Modern Processor Design*
- Hennessy and Patterson, *Computer Architecture: A Quantitative Approach*

## Author

Sashwath Narayanan — University of Washington, ECE