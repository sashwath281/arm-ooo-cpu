`timescale 1ps/1ps

// passive interface that bundles the signals our UVM monitor watches to observe CPU commits. 
// The CPU runs automatically and thus there is no driving. The monitor samples these signals every cycle to reconstruct what committed and when

interface commit_if(input logic clk, input logic reset); 

// committed instruction signals
logic committedValid;               // 1 if the clock cycle the instruction commits.
logic [4:0] committedArchReg;       // the actual reg the value was written to
logic [63:0] committedData;         // the value written to the arch reg
logic [63:0] committedPC;           // the PC of the instruction that committed

// Pipeline state (used for coverage and debug)
logic [63:0] pcOut;                    // current PC of inst being fetched
logic stallOut;                        // is the pipeline stalled this cycle?
logic robFull;                         // is the rob full? (no entries available)
logic robEmpty;                        // is the rob empty? (all 32 entries available)

// Monitor clocking block - all our signals are inputs are the monitor only observes, never drives. 
clocking monitor_cb @(posedge clk);
    default input #1step;              // any input signal is sampled 1 step before the posedge. This aboids race conditions. 
    input committedValid, committedArchReg, committedData, committedPC;
    input pcOut, robEmpty, robFull, stallOut;

endclocking


// modport for the monitor to sample signals
modport monitor_mp (clocking monitor_cb, input reset);      // not used but for correct structure.


endinterface

