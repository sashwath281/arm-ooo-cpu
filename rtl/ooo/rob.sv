`timescale 1ps/1ps

module rob( input logic clk, input logic reset, 

    // Dispatch interface (rename stage pushes new entry)
    input logic dispatch_valid,               // valid instruction
    input logic [4:0] dispatch_arch_dest,     // architectural dest reg (Xn)
    input logic [5:0] dispatch_dest,          // new physical reg holding the result
    input logic [5:0] dispatch_old,           // old physical reg (from RAT, for freeing)
    input logic [63:0] dispatch_pc,           // debug, exception reporting, and mispredict recovery
    input logic dispatch_branch,              // branch
    input logic dispatch_store,               // tells commit to signal the SQ to actually write to memory
    input logic dispatch_load,                // tells commit to signal the LQ to get from memory
    output logic [4:0] dispatch_rob_idx,      // the slot the new entry will occupy
    output logic full,                        // backpressure to dispatch

    // Writeback interface (CDB marks entry complete)
    input logic wb_valid,                     // pulse when execute completes an instruction
    input logic [4:0] wb_rob_idx,             // which ROB entry to update
    input logic wb_branchTaken,               // if instruction is a branch, its actual outcome
    input logic wb_exception,                 // did this instruction fault?

    // Store Writebacks (they never reach CDB)
    input logic store_compl_valid,
    input logic [4:0] store_compl_rob_idx,

    // Commit interface (outputs to rest of pipeline)
    output logic commit_valid,                // is head entry actually ready to reire
    output logic [4:0] commit_arch_dest,      // arch reg being committed
    output logic [5:0] commit_dest,           // phys reg holding the commited value
    output logic [5:0] commit_old,            // old phys reg to free
    output logic commit_store,                // tell SQ to drain this store into thr D-Cache
    output logic commit_load,                 // tell LQ to drain this load
    output logic commit_branch,               // for stats and branch prediction
    output logic [63:0] commit_pc,            // for debug output

    // Flush interface (misprediction)
    output logic flush_valid,                  // a misprediction detected at commit
    output logic [63:0] flush_pc,              // PC of mispredicted branch
    input logic flush_ack,                     // pipeline acknowledged flush
    input logic [4:0] flush_rob_idx           
);

    // ROB entry - 86 bits per entry
    typedef struct packed {
        logic [4:0]  arch_dest;
        logic [5:0]  phys_dest;
        logic [5:0]  phys_old;
        logic [63:0] pc;
        logic branch;
        logic store;
        logic load;
        logic completed;                // starts 0, set to 1 by writeback
        logic branchTaken;             // set by writeback if the entry is a branch
        logic exception;                // set by writeback if execution faulted
        logic valid;                    // set by dispatch 
    } rob_entry_t;


    // Storage: 32 entries
    rob_entry_t entries [0:31];         // FIFO with 32 entries of 86 bits each.
    logic [4:0] head, tail;             // head points to next entry to commit and tail points to next slot for dispatch
    logic [5:0] count;                  // number of live entries


    assign full = (count == 6'd32);     // if count is at max
    assign dispatch_rob_idx = tail;     // dispatch will the correct slot


    // Dispatch logic
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
                entries[tail].phys_dest <= dispatch_dest;
                entries[tail].phys_old  <= dispatch_old;
                entries[tail].pc <= dispatch_pc;
                entries[tail].branch <= dispatch_branch;
                entries[tail].store <= dispatch_store;
                entries[tail].load <= dispatch_load;
                entries[tail].completed <= 1'b0;
                entries[tail].branchTaken <= 1'b0;
                entries[tail].exception <= 1'b0;
                entries[tail].valid <= 1'b1;
                tail <= tail + 1;
            end

            // Writeback
            if (wb_valid) begin
                entries[wb_rob_idx].completed <= 1'b1;
                entries[wb_rob_idx].branchTaken <= wb_branchTaken;
                entries[wb_rob_idx].exception <= wb_exception;

                // For stores
                if(store_compl_valid) begin
                    entries[store_compl_rob_idx].completed <= 1'b1;
                end 

            end

            // Commit retire logic 
            if (commit_valid && !flush_valid) begin         // f the head has an exception, flush_valid fires instead of commit_valid
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
                    if(entries[i].valid && (i > flush_rob_idx)) begin
                        entries[i].valid <= 1'b0;
                        entries[i].completed <= 1'b0;
                    end
                end

                tail <= flush_rob_idx + 1'b1;
                count <= (flush_rob_idx - head) + 1'b1;
            end
        end
    end


    // Commit logic
    assign commit_valid = entries[head].valid && entries[head].completed && !entries[head].exception;
    assign commit_arch_dest = entries[head].arch_dest;
    assign commit_dest = entries[head].phys_dest;
    assign commit_old = entries[head].phys_old;
    assign commit_store = entries[head].store;
    assign commit_load = entries[head].load;
    assign commit_branch = entries[head].branch;
    assign commit_pc = entries[head].pc;


    // Flush detection
    assign flush_valid = entries[head].valid && entries[head].completed && entries[head].exception;
    assign flush_pc = entries[head].pc;

endmodule