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


    // SVA

    // Whenever committedValid is HIGH, committedArchReg, committedData, and committedPC must all be fully Defined. 
    // no X/Z bits, no Exceptions. chcekd every cycle (except during reset)
    property p_no_x_when_valid;
        @(posedge clk) disable iff (reset)
        committedValid |-> (!$isunknown(committedArchReg) && !$unknown(committedData) && !$unknown(committedPC));
    endproperty

    a_no_x_when_valid: assert property (p_no_x_when_valid)
        else $error("[SVA] X/Z detected on the committed signals when committedValid = 1");
    

    // Whenever reset is HIGH, nothing should commit (committedValid must be LOW)
    // checked same cycle
    property p_no_commit_during_reset;
        @(posedge clk)
        reset |-> !committedValid;
    endproperty

    a_no_commit_during_reset: assert property (p_no_commit_during_reset)
        else $error("[SVA] committedValid asserted during reset");


    // whenever we commit, the arch reg committing too should be between X0 and X30
    // Not on reset
    property p_arch_reg_in_range;
        @(posedge clk) disable iff (reset)
        committedValid |-> (committedArchReg <= 5'd30);
    endproperty

    a_arch_reg_in_range: assert property (p_arch_reg_in_range)
        else $error("[SVA] committedArchReg=%0d exceeds the valid range (0-30)", committedArchReg);


    // whenever we commit, the instruction should be word aligned (All LEGv8 instructions are mutiples of 4)
    // we check the bottom two bits for 00. 
    property p_pc_aligned;
        @(posedge clk) disable iff (reset)
        committedValid |-> (committedPC[1:0] == 2'b00);
    endproperty

    a_pc_aligned: assert property (p_pc_aligned)
        else $error("[SVA] committedPC=0x%h is not 4-byte aligned", committedPC);


    // ROB should never be full and empty at the same time - Messed up ROB otherwise
    property p_rob_not_full_and_empty;
        @(posedge clk) disable iff (reset)
        !(robFull && robEmpty);
    endproperty

    a_rob_not_full_and_empty: assert property (p_rob_not_full_and_empty)
        else $error("[SVA] ROB is full AND empty simultaneously");


    // The FETCH side PC should be word aligned
    // we check the bottom two bits for 00 directly everytime.
    property p_fetch_pc_aligned;
        @(posedge clk) disable iff (reset)
        (pcOut[1:0] == 2'b00);
    endproperty

    a_fetch_pc_aligned: assert property (p_fetch_pc_aligned)
        else $error("[SVA] pcOut=0x%h is not 4-byte aligned", pcOut);


endinterface

