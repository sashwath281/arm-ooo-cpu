`timescale 1ps/1ps

module gshare(clk, reset, predict_pc, predict_taken, predict_bhr_snapshot, update_valid, update_pc, update_bhr, update_taken);
    
    input logic clk;
    input logic reset;

    // Predict interface - used in IF stage every cycle
    input logic [63:0] predict_pc;                      // current fetch instruction
    output logic predict_taken;                         // our guess (1 if taken)
    output logic [7:0] predict_bhr_snapshot;            // the BHR value at predict time, sent down the pipeline with instruction

    // Update interface - used when branch resolves at EX stage
    input  logic update_valid;                          // pulses high for one cycle if branch resolved
    input  logic [63:0] update_pc;                      // PC of the resolved branch
    input  logic [7:0] update_bhr;                      // the snapshot we carried down the pipeline
    input  logic update_taken;                          // actual outcome 

    
    // State
    logic [1:0] pht [0:255];                            // 256 entries, each a 2-bit counter
    logic [7:0] bhr;                                    // 8-bit branch history register

    // Predict path        
    logic [7:0] predict_index;

    // Skip 2 LSBs of PC (word-aligned), then XOR with BHR
    assign predict_index = predict_pc[9:2] ^ bhr;       // pick a slot
    assign predict_taken = pht[predict_index][1];       // top bit
    assign predict_bhr_snapshot = bhr;                  // send the BHR out

    
    // Update path
    logic [7:0] update_index;
    assign update_index = update_pc[9:2] ^ update_bhr;

    integer i;
    initial begin
        for (i = 0; i < 256; i++)
            pht[i] = 2'b01;
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            bhr <= 8'b0;
        end

        else if (update_valid) begin
            // 2-bit saturating counter update
            if (update_taken) begin
                if (pht[update_index] != 2'b11)
                    pht[update_index] <= pht[update_index] + 1;
            end
            
            else begin
                if (pht[update_index] != 2'b00)
                    pht[update_index] <= pht[update_index] - 1;
            end

            // Shift actual outcome into BHR
            bhr <= {bhr[6:0], update_taken};
        end
    end

endmodule