`timescale 1ps/1ps

module issueQueue (
    input logic clk,
    input logic reset,

    // Dispatch
    input logic dispatch_valid,                     // Same from dispatch stage
    input logic [5:0] dispatch_dest,
    input logic [5:0] dispatch_source1,
    input logic [5:0] dispatch_source2,
    input logic dispatch_source1_ready,
    input logic dispatch_source2_ready,
    input logic [4:0] dispatch_rob_idx,
    input logic [1:0] dispatch_alu_op,
    input logic dispatch_load,
    input logic dispatch_store,
    input logic [63:0] dispatch_immediate,
    input logic dispatch_imm,
    input logic dispatch_uncondBranch,
    input logic dispatch_condBranch,
    input logic [63:0] dispatch_branchTarget,
    input logic dispatch_branch_cbz,
    output logic full,

    // Wakeup interface (from CDB)
    input logic wakeup_valid,                       // an instruction just finished and its result is on the CDB
    input logic [5:0] wakeup_phys_reg,              // which physical reg holds the new result. 

    // Select interface to execute
    output logic issue_valid,                       // Outputs
    output logic [5:0] issue_dest,
    output logic [5:0] issue_source1,
    output logic [5:0] issue_source2,
    output logic [4:0] issue_rob_idx,
    output logic [1:0] issue_alu_op,
    output logic issue_load,
    output logic issue_store,
    output logic [63:0] issue_immediate,
    output logic issue_imm,
    output logic issue_uncondBranch,
    output logic issue_condBranch,
    output logic [63:0] issue_branchTarget,
    output logic issue_branch_cbz,

    // Flush
    input logic flush);


    // 16-entry struct - 157 bits each
    typedef struct packed {
        logic valid;                        // slot in use
        logic [5:0] phys_dest;
        logic [5:0] phys_source1;
        logic [5:0] phys_source2;
        logic source1_ready;                // scheduling bits, flipped by wakeup
        logic source2_ready;                // scheduling bits, flipped by wakeup
        logic [4:0] rob_idx;
        logic [1:0] alu_op;
        logic load;
        logic store;
        logic [63:0] immediate;
        logic imm;                          // is source2 an immediate?
        logic [63:0] branchTarget;
        logic uncondBranch;
        logic condBranch;
        logic branch_cbz;
    } iq_entry_t;

    iq_entry_t entries [0:15];


    // Full detection
    logic [4:0] valid_count;
    
    always_comb begin
        valid_count = 0;
        for (int i = 0; i < 16; i++)
            if (entries[i].valid) 
                valid_count = valid_count + 1;
    end

    assign full = (valid_count == 5'd16);


    // Find free slot for dispatch
    logic [3:0] free_slot;          // excat free slot number
    logic free_found;               // toggle if slot is found
    
    // Scan entries 0 through 15 looking for the first one with valid = 0.
    // Once found, remember the index and set free_found. 
    always_comb begin
        free_slot  = 4'd0;
        free_found = 1'b0;
        for (int i = 0; i < 16; i++) begin
            if (!entries[i].valid && !free_found) begin
                free_slot  = 4'(i);
                free_found = 1'b1;
            end
        end
    end


    // Select the ready entry. pick lowest-index ready entry.
    logic [3:0] select_slot;        // the lowest-index entry with both the operands available
    logic select_found;             // toggle after we find the instruction matching the conditions
    
    always_comb begin
        select_slot  = 4'd0;
        select_found = 1'b0;
        for (int i = 0; i < 16; i++) begin
            if (entries[i].valid && entries[i].source1_ready && 
                entries[i].source2_ready && !select_found) begin
                select_slot  = 4'(i);
                select_found = 1'b1;
            end
        end
    end


    // Issue outputs
    assign issue_valid = select_found;
    assign issue_dest = entries[select_slot].phys_dest;
    assign issue_source1 = entries[select_slot].phys_source1;
    assign issue_source2 = entries[select_slot].phys_source2;
    assign issue_rob_idx = entries[select_slot].rob_idx;
    assign issue_alu_op = entries[select_slot].alu_op;
    assign issue_load = entries[select_slot].load;
    assign issue_store = entries[select_slot].store;
    assign issue_immediate = entries[select_slot].immediate;
    assign issue_imm = entries[select_slot].imm;
    assign issue_uncondBranch = entries[select_slot].uncondBranch;
    assign issue_condBranch = entries[select_slot].condBranch;
    assign issue_branchTarget = entries[select_slot].branchTarget;
    assign issue_branch_cbz = entries[select_slot].branch_cbz;


    // Sequential logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 0; i < 16; i++)
                entries[i].valid <= 1'b0;
        end

        else if (flush) begin
            for (int i = 0; i < 16; i++)
                entries[i].valid <= 1'b0;
        end

        else begin
            // Wakeup - For every valid entry, compare source1 and source2 against the broadcast physical reg.
            if (wakeup_valid) begin
                for (int i = 0; i < 16; i++) begin
                    if (entries[i].valid) begin
                        if (entries[i].phys_source1 == wakeup_phys_reg)
                            entries[i].source1_ready <= 1'b1;                   // Toggle ready bit
                        if (entries[i].phys_source2 == wakeup_phys_reg)
                            entries[i].source2_ready <= 1'b1;                      // Toggle ready bit
                    end
                end
            end

            // Dispatch insertion
            if (dispatch_valid && free_found) begin
                entries[free_slot].valid <= 1'b1;
                entries[free_slot].phys_dest <= dispatch_dest;
                entries[free_slot].phys_source1 <= dispatch_source1;
                entries[free_slot].phys_source2 <= dispatch_source2;
                entries[free_slot].source1_ready <= dispatch_source1_ready || (wakeup_valid && wakeup_phys_reg == dispatch_source1);
                entries[free_slot].source2_ready <= dispatch_source2_ready || dispatch_imm || (wakeup_valid && wakeup_phys_reg == dispatch_source2);
                entries[free_slot].rob_idx <= dispatch_rob_idx;
                entries[free_slot].alu_op <= dispatch_alu_op;
                entries[free_slot].load <= dispatch_load;
                entries[free_slot].store <= dispatch_store;
                entries[free_slot].immediate <= dispatch_immediate;
                entries[free_slot].imm <= dispatch_imm;
                entries[free_slot].branchTarget <= dispatch_branchTarget;
                entries[free_slot].uncondBranch <= dispatch_uncondBranch;
                entries[free_slot].condBranch <= dispatch_condBranch;
                entries[free_slot].branch_cbz <= dispatch_branch_cbz;
                
            end


            // Dequeue - once we issue an instruction, free its IQ slot
            if (select_found)
                entries[select_slot].valid <= 1'b0;
        end
    end

endmodule