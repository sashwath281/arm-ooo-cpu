`timescale 1ps/1ps

module issueQueue (
    input logic clk,
    input logic reset,

    // Dispatch
    input logic dispatch_valid,                     // Same from dispatch stage
    input logic [5:0] dispatch_dest,
    input logic [5:0] dispatch_source1,
    input logic [5:0] dispatch_source2,
    input logic dispatch_branchReg,
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
    input logic [3:0] dispatch_sq_idx,
    input logic [3:0] dispatch_lq_idx,
    input logic [63:0] dispatch_pc,
    input logic dispatch_predictedTaken,
    input logic [63:0] dispatch_predictedTarget,
    
    input logic dispatch_flagSet,                   // Flag for conditional branches
    input logic flags_write_done,
    output logic full,

    // Wakeup interface (from CDB)
    input logic wakeup_valid,                       // an instruction just finished and its result is on the CDB
    input logic [5:0] wakeup_phys_reg,              // which physical reg holds the new result. 

    // Select interface to execute
    output logic issue_valid,                       // Outputs
    output logic [5:0] issue_dest,
    output logic [5:0] issue_source1,
    output logic [5:0] issue_source2,
    output logic issue_branchReg,
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
    output logic [3:0] issue_sq_idx,
    output logic [3:0] issue_lq_idx,
    output logic [63:0] issue_pc,
    output logic [63:0] issue_predictedTarget,
    output logic issue_predictedTaken,
    output logic issue_flagSet,                     // flags for conditional branches

    // Flush
    input logic flush,
    input logic [4:0] flush_rob_idx);


    // 16-entry struct
    typedef struct packed {
        logic valid;                        // slot in use
        logic [5:0] phys_dest;
        logic [5:0] phys_source1;
        logic [5:0] phys_source2;
        logic source1_ready;                // scheduling bits, flipped by wakeup
        logic source2_ready;                // scheduling bits, flipped by wakeup
        logic branchReg;
        logic [4:0] rob_idx;
        logic [1:0] alu_op;
        logic load;
        logic store;
        logic [3:0] sq_idx;
        logic [3:0] lq_idx;
        logic [63:0] immediate;
        logic imm;                          // is source2 an immediate?
        logic [63:0] branchTarget;
        logic uncondBranch;
        logic condBranch;
        logic branch_cbz;
        logic [63:0] pc;
        logic predictedTaken;
        logic [63:0] predictedTarget;
        logic flagSet;
        logic needFlag;

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
    
    logic flags_busy;

    always_comb begin
        select_slot  = 4'd0;
        select_found = 1'b0;
        for (int i = 0; i < 16; i++) begin
            if (entries[i].valid && entries[i].source1_ready && 
                entries[i].source2_ready && !select_found &&
                (!entries[i].needFlag || !flags_busy)) begin
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
    assign issue_branchReg = entries[select_slot].branchReg;
    assign issue_rob_idx = entries[select_slot].rob_idx;
    assign issue_alu_op = entries[select_slot].alu_op;
    assign issue_load = entries[select_slot].load;
    assign issue_store = entries[select_slot].store;
    assign issue_sq_idx = entries[select_slot].sq_idx;
    assign issue_lq_idx = entries[select_slot].lq_idx;
    assign issue_immediate = entries[select_slot].immediate;
    assign issue_imm = entries[select_slot].imm;
    assign issue_uncondBranch = entries[select_slot].uncondBranch;
    assign issue_condBranch = entries[select_slot].condBranch;
    assign issue_branchTarget = entries[select_slot].branchTarget;
    assign issue_branch_cbz = entries[select_slot].branch_cbz;
    assign issue_pc = entries[select_slot].pc;
    assign issue_predictedTaken = entries[select_slot].predictedTaken;
    assign issue_predictedTarget = entries[select_slot].predictedTarget;
    assign issue_flagSet = entries[select_slot].flagSet;


    // Sequential logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 0; i < 16; i++)
                entries[i].valid <= 1'b0;
        end

        else if (flush) begin
            for (int i = 0; i < 16; i++)
                if(entries[i].valid && (entries[i].rob_idx > flush_rob_idx)) begin
                    entries[i].valid <= 1'b0;
                end

                if (select_found && entries[select_slot].rob_idx == flush_rob_idx) begin
                    entries[select_slot].valid <= 1'b0;
                end
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
                entries[free_slot].branchReg <= dispatch_branchReg;
                entries[free_slot].rob_idx <= dispatch_rob_idx;
                entries[free_slot].alu_op <= dispatch_alu_op;
                entries[free_slot].load <= dispatch_load;
                entries[free_slot].store <= dispatch_store;
                entries[free_slot].sq_idx <= dispatch_sq_idx;
                entries[free_slot].lq_idx <= dispatch_lq_idx;
                entries[free_slot].immediate <= dispatch_immediate;
                entries[free_slot].imm <= dispatch_imm;
                entries[free_slot].branchTarget <= dispatch_branchTarget;
                entries[free_slot].uncondBranch <= dispatch_uncondBranch;
                entries[free_slot].condBranch <= dispatch_condBranch;
                entries[free_slot].branch_cbz <= dispatch_branch_cbz;
                entries[free_slot].pc <= dispatch_pc;
                entries[free_slot].predictedTaken <= dispatch_predictedTaken;
                entries[free_slot].predictedTarget <= dispatch_predictedTarget;
                entries[free_slot].flagSet <= dispatch_flagSet;
                entries[free_slot].needFlag <= dispatch_condBranch && !dispatch_branch_cbz;   

            end


            // Dequeue - once we issue an instruction, free its IQ slot
            if (select_found)
                entries[select_slot].valid <= 1'b0;
        end
    end


    always_ff @(posedge clk or posedge reset) begin
        if(reset)
            flags_busy <= 1'b0;
        
        else begin
            if(flags_write_done)
                flags_busy <= 1'b0;

            if(dispatch_valid && dispatch_flagSet)
                flags_busy <= 1'b1; 
            
        end 
    end 


endmodule