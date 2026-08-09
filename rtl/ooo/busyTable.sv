`timescale 1ps/1ps

module busyTable (clk, reset, set_valid, set_preg, clear_valid, clear_preg, read_preg1, read_preg2, busy1, busy2);
    input logic clk;
    input logic reset;

    // driven by rename when it allocates a fresh destination. 
    input logic set_valid;                       // pulse when a new destination is being allocated
    input logic [5:0] set_preg;                  // which physical register should be marked busy. 

    // driven by the CDB when a result is broadcast
    input logic clear_valid;                     // pulse when an instruction's result is being written
    input logic [5:0] clear_preg;               // which phys reg is now valid. 

    // driven by rename to check both sources
    input logic [5:0] read_preg1;                // phys reg 1 to check
    input logic [5:0] read_preg2;                // phys reg 2 to check
    output logic busy1;                          // status of phys reg 1
    output logic busy2;                          // status of phys reg 2

    // Storage 
    logic [63:0] busy;                           // Storage in the form of 64 flip flops for each physical register. 
                                                 // 1 = busy, 0 = valid.
    
    // Read ports — combinational
    assign busy1 = busy[read_preg1];             // status of phys reg 1
    assign busy2 = busy[read_preg2];             // status of phys reg 2


    always_ff @(posedge clk or posedge reset) begin
        
        if (reset) begin
            busy <= 64'b0;    // all regs valid at startup
        end
        
        else begin
            if (clear_valid)
                busy[clear_preg] <= 1'b0;
            if (set_valid)
                busy[set_preg] <= 1'b1;
        end
    end

endmodule