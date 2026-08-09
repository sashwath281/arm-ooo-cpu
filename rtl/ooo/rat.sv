`timescale 1ps/1ps

module rat (clk, reset, read_reg1, read_reg2, read_preg1, read_preg2, write_valid, write_reg, write_preg_old, write_preg_new, checkpoint_valid, checkpoint_id, restore_valid, restore_id);
    input logic clk;
    input logic reset;

    // Read ports (rename stage looks up sources)
    input logic [4:0] read_reg1;            // the architectural register number to look up for source 1.
    input logic [4:0] read_reg2;            // the architectural register number to look up for source 2.
    output logic [5:0] read_preg1;          // the physical register number for source 1.
    output logic [5:0] read_preg2;          // the physical register number for source 2.

    // Write port (rename stage updates dest mapping)
    input logic write_valid;                // pulse when rename is actually installing a new mapping.
    input logic [4:0] write_reg;            // the architectural register number to update.
    output logic [5:0] write_preg_old;      // the physical register - old mapping (ROB saves this for freeing)
    input logic [5:0] write_preg_new;       // the physical register - new mapping from free list

    // Checkpoint (snapshot for misprediction recovery)
    input logic checkpoint_valid;           // pulse when rename is taking a snapshot of the mapping table.
    input logic [4:0] checkpoint_id;        // which checkpoint to save to (0-31)
    
    // Restore (on misprediction)
    input logic restore_valid;              // pulse when rename is restoring a snapshot of the mapping table.
    input logic [4:0] restore_id;           // which checkpoint to restore from (0-31)


    // storage
    logic [5:0] mapping [0:31];             // which physical reg does this arch reg point to right now. 
    logic [5:0] checkpoints [0:31][0:31];   // [checkpoint_id][arch_reg]


    // Read ports — combinational
    assign read_preg1 = mapping[read_reg1];         // the 6 bit physical register number for source 1.
    assign read_preg2 = mapping[read_reg2];         // the 6 bit physical register number for source 2.
    assign write_preg_old = mapping[write_reg];     // the 6 bit physical register number for the old mapping of the destination arch reg.


    always_ff @(posedge clk or posedge reset) begin
        
        if (reset) begin
            // Identity mapping: X0→P0, X1→P1, ... X31→P31
            for (int i = 0; i < 32; i++)
                mapping[i] <= 6'(i);
        end
        
        else begin
            // Update mapping
            if (write_valid)
                mapping[write_reg] <= write_preg_new;

            // Save checkpoint
            if (checkpoint_valid) begin
                for (int i = 0; i < 32; i++)
                    checkpoints[checkpoint_id][i] <= mapping[i];
                // Also capture the current write if happening same cycle
                if (write_valid)
                    checkpoints[checkpoint_id][write_reg] <= write_preg_new;
            end

            // Restore checkpoint (overrides normal write)
            if (restore_valid) begin
                for (int i = 0; i < 32; i++)
                    mapping[i] <= checkpoints[restore_id][i];
            end
        end
    end

endmodule