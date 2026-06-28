`timescale 1ps/1ps

module rat (clk, reset, read_areg1, read_areg2, read_preg1, read_preg2, write_valid, write_areg, write_preg_old, write_preg_new, checkpoint_valid, checkpoint_id, restore_valid, restore_id);
    input logic clk;
    input logic reset;

    // Read ports (rename stage looks up sources)
    input logic [4:0] read_areg1;
    input logic [4:0] read_areg2;
    output logic [5:0] read_preg1;
    output logic [5:0] read_preg2;

    // Write port (rename stage updates dest mapping)
    input logic write_valid;
    input logic [4:0] write_areg;
    output logic [5:0] write_preg_old;    // old mapping (ROB saves this for freeing)
    input logic [5:0] write_preg_new;     // new mapping from free list

    // Checkpoint (snapshot for misprediction recovery)
    input logic checkpoint_valid;
    input logic [4:0] checkpoint_id;
    
    // Restore (on misprediction)
    input logic restore_valid;
    input logic [4:0] restore_id;


    // 32 arch regs → 6-bit phys reg number each
    logic [5:0] mapping [0:31];

    // Checkpoint storage: up to 32 snapshots (one per possible in-flight branch)
    logic [5:0] checkpoints [0:31][0:31];       // [checkpoint_id][arch_reg]

    // Read ports — combinational
    assign read_preg1 = mapping[read_areg1];
    assign read_preg2 = mapping[read_areg2];
    assign write_preg_old = mapping[write_areg];


    always_ff @(posedge clk or posedge reset) begin
        
        if (reset) begin
            // Identity mapping: X0→P0, X1→P1, ... X31→P31
            for (int i = 0; i < 32; i++)
                mapping[i] <= 6'(i);
        end
        
        else begin
            // Update mapping
            if (write_valid)
                mapping[write_areg] <= write_preg_new;

            // Save checkpoint
            if (checkpoint_valid) begin
                for (int i = 0; i < 32; i++)
                    checkpoints[checkpoint_id][i] <= mapping[i];
                // Also capture the current write if happening same cycle
                if (write_valid)
                    checkpoints[checkpoint_id][write_areg] <= write_preg_new;
            end

            // Restore checkpoint (overrides normal write)
            if (restore_valid) begin
                for (int i = 0; i < 32; i++)
                    mapping[i] <= checkpoints[restore_id][i];
            end
        end
    end

endmodule