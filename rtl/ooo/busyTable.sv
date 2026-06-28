`timescale 1ps/1ps

module busy_table (clk, reset, set_valid, set_preg, clear_valid, clear_preg, read_preg1, read_preg2, busy1, busy2);
    input logic clk;
    input logic reset;

    // Set busy (rename stage — new dest allocated)
    input logic set_valid;
    input logic [5:0] set_preg;

    // Clear busy (writeback — result broadcast on CDB)
    input logic clear_valid;
    input logic [5:0]  clear_preg;

    // Read ports (rename stage checks if sources are ready)
    input logic [5:0] read_preg1;
    input logic [5:0] read_preg2;
    output logic busy1;
    output logic busy2;

    logic [63:0] busy;

    // Read ports — combinational
    assign busy1 = busy[read_preg1];
    assign busy2 = busy[read_preg2];


    always_ff @(posedge clk or posedge reset) begin
        
        if (reset) begin
            busy <= 64'b0;    // all regs valid at startup
        end
        
        else begin
            // Clear has priority over set (if same reg clears and sets
            // in same cycle, the new instruction's set should win,
            // but the clearing instruction's result IS available
            // for bypass — handle in IQ wakeup, not here)
            if (clear_valid)
                busy[clear_preg] <= 1'b0;
            if (set_valid)
                busy[set_preg] <= 1'b1;
        end
    end

endmodule