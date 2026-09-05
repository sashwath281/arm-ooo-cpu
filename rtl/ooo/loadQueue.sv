`timescale 1ps/1ps

module loadQueue (
    input logic clk,
    input logic reset,

    // Dispatch interface
    input logic dispatch_valid,             
    output logic [3:0] dispatch_lq_idx,         // slot assigned out of the 16
    output logic full,                          // the LQ full?
    input logic [5:0] dispatch_dest,            // Identity token from Rename
    input logic [4:0] dispatch_rob_idx,  
    output logic [5:0] result_phys_dest,        // To CDB Arbiter
    output logic [4:0] result_rob_idx,      

    // Execute - load computes address and requests data
    input logic exec_valid,
    input logic [3:0] exec_lq_idx,
    input logic [63:0] exec_addr,               // the address

    // Store queue forwarding result
    input logic sq_fwd_hit,
    input logic [63:0] sq_fwd_data,
    output logic [4:0] sq_rob_idx,

    // D-Cache interface
    output logic dcache_req,
    output logic [63:0] dcache_addr,
    input logic dcache_resp_valid,
    input logic [63:0] dcache_resp_data,

    // Result to CDB
    output logic result_valid,
    output logic [63:0] result_data,
    output logic [3:0] result_lq_idx,

    // Commit interface when ROB retires load. 
    input logic commit_valid,

    // Flush
    input logic flush,
    input logic [4:0] flush_rob_idx);   // the mispredicted branch's IDX


    // struct with 2272 bits of data
    typedef struct packed {
        logic valid;
        logic addr_valid;
        logic completed;
        logic [63:0] addr;
        logic [63:0] data;
        logic [5:0] phys_dest;
        logic [4:0] rob_idx;   
    } lq_entry_t;

    lq_entry_t entries [0:15];


    // Head = oldest store (next to commit)
    // tail = next free slot
    logic [3:0] head, tail;
    logic [4:0] count;

    assign full = (count == 5'd16);         // the SQ is full. 
    assign dispatch_lq_idx = tail;          // the slot is the tail of FIFO.


    // Execute
    // Check SQ forwarding first, then go to D-Cache
    logic need_cache;
    logic [3:0] active_idx;                 // which LQ entry is waiting 
    logic exec_pending;                     // are we waiting from D-Cache


    always_ff @(posedge clk or posedge reset) begin
        
        if (reset) begin
            for (int i = 0; i < 16; i++) begin
                entries[i].valid <= 1'b0;
                entries[i].completed <= 1'b0;
            end
            head <= 4'd0;
            tail <= 4'd0;
            count <= 5'd0;
            exec_pending <= 1'b0;
            active_idx <= 4'd0;
        end
        
        else if (flush) begin
            for (int i = 0; i < 16; i++) begin
                if (entries[i].valid && entries[i].rob_idx >= flush_rob_idx) begin
                    
                    entries[i].valid <= 1'b0;       // Kill the load that came after the mispredicted branch
                    entries[i].completed <= 1'b0;
                end
            end
            exec_pending <= 1'b0;
        end
        
        else begin
            // Dispatch - allocate entry at tail
            if (dispatch_valid && !full) begin
                entries[tail].valid <= 1'b1;
                entries[tail].phys_dest <= dispatch_dest;
                entries[tail].rob_idx <= dispatch_rob_idx; 
                entries[tail].addr_valid <= 1'b0;
                entries[tail].completed <= 1'b0;
                entries[tail].addr <= 64'd0;
                entries[tail].data <= 64'd0;
                tail  <= tail + 1;
                count <= count + 1;
            end

            // Execute - address arrives
            if (exec_valid && !exec_pending) begin
                entries[exec_lq_idx].addr <= exec_addr;
                entries[exec_lq_idx].addr_valid <= 1'b1;

                if (sq_fwd_hit) begin
                    // Got data from store queue
                    entries[exec_lq_idx].data <= sq_fwd_data;
                    entries[exec_lq_idx].completed <= 1'b1;
                end

                else begin
                    exec_pending <= 1'b1;           // Need to go to D-Cache
                    active_idx <= exec_lq_idx;
                end
            end


            // D-Cache response
            if (dcache_resp_valid && exec_pending) begin
                entries[active_idx].data <= dcache_resp_data;
                entries[active_idx].completed <= 1'b1;
                exec_pending <= 1'b0;
            end

            // Commit: retire head
            if (commit_valid) begin
                entries[head].valid <= 1'b0;
                head <= head + 1;
                count <= count - 1;
            end

            if (dispatch_valid && !full && commit_valid) 
                count <= count;

        end
    end


    //D-Cache request
    assign dcache_req = exec_pending && !entries[active_idx].completed;
    assign dcache_addr = entries[active_idx].addr;

    // Result output
    // Drive result when a load completes (either from SQ or D-Cache)
    assign result_valid = (exec_valid && sq_fwd_hit) || (dcache_resp_valid && exec_pending);                  
    assign result_data = (exec_valid && sq_fwd_hit) ? sq_fwd_data : dcache_resp_data;
    assign result_lq_idx = (exec_valid && sq_fwd_hit) ? exec_lq_idx : active_idx;
    assign result_phys_dest = (exec_valid && sq_fwd_hit) ? entries[exec_lq_idx].phys_dest : entries[active_idx].phys_dest;
    assign result_rob_idx   = (exec_valid && sq_fwd_hit) ? entries[exec_lq_idx].rob_idx   : entries[active_idx].rob_idx;
    assign sq_rob_idx = entries[exec_lq_idx].rob_idx;

endmodule