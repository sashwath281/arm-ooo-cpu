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

## Known Limitations

- **D-Cache not implemented**: Loads return a placeholder value. Building the D-Cache and an arbiter between the LQ read and SQ drain paths is the next thing on the list.

- **NZCV flag renaming not implemented**: The current implementation uses the branch instruction's own ALU output rather than renamed prior flags. Adding NZCV as a separately-renamed architectural resource would fix this.

- **Complex branch recovery edge case**: some CBZ/B sequences trigger a bug in the recovery unit's redirect PC path. Isolated, not yet fixed.

- **BL (Branch-and-Link) disabled**: Return address (PC+4) isn't wired through the rename pipeline yet.

## Roadmap

Next up:
- Fix the branch recovery redirect PC bug
- Build the D-Cache and arbiter mux for LQ read vs SQ drain
- Add NZCV renaming so B.LT works

UVM env:
- Full UVM testbench with agents, sequences, scoreboard
- SVA covering pipeline invariants
- Functional coverage for OoO scheduling scenarios
- Automated regression suite

Vivado synth:
- Target Xilinx Artix-7
- Characterize Fmax
- Analyze critical path (expected through RAT read - PRF address - ALU output)

Later:
- 2-issue OoO with dual CDBs
- L2 cache with real DRAM model
- Extend to full AArch64 ISA

## Building / Running


## Author

Sashwath Narayanan — University of Washington, ECE
