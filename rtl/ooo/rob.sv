`timescale 1ps/1ps

module rob(
    input logic clk,
    input logic reset,

    // Dispatch interface (rename stage pushes new entry)
    input logic dispatch_valid,
    input logic [4:0] dispatch_arch_dest,     // architectural dest reg (Xn)
    input logic [5:0] dispatch_phys_dest,     // new physical reg (from free list)
    input logic [5:0] dispatch_phys_old,      // old physical reg (from RAT, for freeing)
    input logic [63:0] dispatch_pc,           // PC of this instruction
    input logic dispatch_is_branch,           // is this a branch?
    input logic dispatch_is_store,            // is this a store?
    output logic [4:0] dispatch_rob_idx,      // ROB slot assigned (used as tag)
    output logic full,                        // stall rename if full

    // Writeback interface (CDB marks entry complete)
    input logic wb_valid,
    input logic [4:0] wb_rob_idx,       // which ROB entry finished
    input logic wb_branch_taken,        // actual branch outcome (if branch)
    input logic wb_exception,           // did this instruction fault?

    // Commit interface (outputs to rest of pipeline)
    output logic commit_valid,                 // an instruction is committing this cycle
    output logic [4:0] commit_arch_dest,       // arch reg being committed
    output logic [5:0] commit_phys_dest,       // phys reg being committed
    output logic [5:0] commit_phys_old,        // old phys reg to free
    output logic commit_is_store,              // tell SQ to drain this store
    output logic commit_is_branch,             // for stats
    output logic [63:0] commit_pc,             // for debug

    // Flush interface (misprediction)
    output logic flush_valid,                  // a misprediction detected at commit
    output logic [63:0] flush_pc,              // PC of mispredicted branch
    input logic flush_ack                      // pipeline acknowledged flush
);

    // ROB entry
    typedef struct packed {
        logic [4:0]  arch_dest;
        logic [5:0]  phys_dest;
        logic [5:0]  phys_old;
        logic [63:0] pc;
        logic        is_branch;
        logic        is_store;
        logic        completed;
        logic        branch_taken;
        logic        exception;
        logic        valid;
    } rob_entry_t;

    // Storage: 32 entries
    rob_entry_t entries [0:31];

    // Head and tail pointers
    logic [4:0] head, tail;
    logic [5:0] count;

    assign full = (count == 6'd32);
    assign dispatch_rob_idx = tail;


    // Dispatch: push new entry at tail
    always_ff @(posedge clk or posedge reset) begin
        
        if (reset) begin
            for (int i = 0; i < 32; i++) begin
                entries[i].valid <= 1'b0;
                entries[i].completed <= 1'b0;
            end
            head  <= 5'd0;
            tail  <= 5'd0;
            count <= 6'd0;
        end

        else begin
            // Dispatch
            if (dispatch_valid && !full) begin
                entries[tail].arch_dest <= dispatch_arch_dest;
                entries[tail].phys_dest <= dispatch_phys_dest;
                entries[tail].phys_old  <= dispatch_phys_old;
                entries[tail].pc <= dispatch_pc;
                entries[tail].is_branch <= dispatch_is_branch;
                entries[tail].is_store <= dispatch_is_store;
                entries[tail].completed <= 1'b0;
                entries[tail].branch_taken <= 1'b0;
                entries[tail].exception <= 1'b0;
                entries[tail].valid <= 1'b1;
                tail <= tail + 1;
            end

            // Writeback: mark entry complete
            if (wb_valid) begin
                entries[wb_rob_idx].completed <= 1'b1;
                entries[wb_rob_idx].branch_taken <= wb_branch_taken;
                entries[wb_rob_idx].exception <= wb_exception;
            end

            // Commit: retire head if complete
            if (commit_valid && !flush_valid) begin
                entries[head].valid <= 1'b0;
                head <= head + 1;
            end

            // Count management
            if (dispatch_valid && !full && commit_valid && !flush_valid)
                count <= count;             // one in, one out
            else if (dispatch_valid && !full)
                count <= count + 1;
            else if (commit_valid && !flush_valid)
                count <= count - 1;

            // Flush: clear everything on misprediction
            if (flush_ack) begin
                for (int i = 0; i < 32; i++) begin
                    entries[i].valid <= 1'b0;
                    entries[i].completed <= 1'b0;
                end

                head  <= 5'd0;
                tail  <= 5'd0;
                count <= 6'd0;
            end
        end
    end


    // Commit logic (combinational)
    assign commit_valid = entries[head].valid && entries[head].completed && !entries[head].exception;
    assign commit_arch_dest = entries[head].arch_dest;
    assign commit_phys_dest = entries[head].phys_dest;
    assign commit_phys_old  = entries[head].phys_old;
    assign commit_is_store  = entries[head].is_store;
    assign commit_is_branch = entries[head].is_branch;
    assign commit_pc = entries[head].pc;


    // Flush detection (combinational)
    // Exception at head → flush
    assign flush_valid = entries[head].valid && entries[head].completed && entries[head].exception;
    assign flush_pc = entries[head].pc;

endmodule