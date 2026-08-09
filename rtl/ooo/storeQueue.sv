`timescale 1ps/1ps

module storeQueue (
    input logic clk,
    input logic reset,

    // Dispatch interface - reserves a slot when a store is dispatched
    input logic dispatch_valid,            
    output logic [3:0] dispatch_sq_idx,    // SQ slot assigned
    output logic full,                     // is the SQ full?

    // Execute (write) - fills in addr and the data when the store is executed
    input logic write_valid,
    input logic [3:0] write_sq_idx,
    input logic [63:0] write_addr,
    input logic [63:0] write_data,
    

    // Forwarding interface (load checks SQ for matching store)
    input logic fwd_req_valid,
    input logic [63:0] fwd_req_addr,
    output logic fwd_hit,
    output logic [63:0] fwd_data,

    // Commit - drains the head store to D-Cache
    input logic commit_valid,
    output logic commit_ready,        // oldest store has addr+data
    output logic [63:0] commit_addr,
    output logic [63:0] commit_data,

    // Every instruction gets a ROB slot at dispatch, in program order.
    input logic [4:0] dispatch_rob_idx,

    input logic [4:0] fwd_rob_idx,      // load's rob IDX
    input logic [4:0] flush_rob_idx,    // the mispredicted branch's IDX

    // Flush
    input logic flush);

    // struct wuth 2176 bits of storage
    typedef struct packed {
        logic valid;
        logic addr_valid;     // address computed?
        logic data_valid;     // data available?
        logic [63:0] addr;
        logic [63:0] data;
        logic [4:0] rob_idx;    // the ROB slot from dispatch
    } sq_entry_t;

    sq_entry_t entries [0:15];

    // Head = oldest store (next to commit)
    // tail = next free slot
    logic [3:0] head, tail;
    logic [4:0] count;

    assign full = (count == 5'd16);     // the SQ is full. 
    assign dispatch_sq_idx = tail;      // the slot is the tail of FIFO.


    // Commit outputs
    
    // commit_ready = 1 when the head store has both address and data. 
    assign commit_ready = entries[head].valid && entries[head].addr_valid && entries[head].data_valid;
    assign commit_addr = entries[head].addr;    // address of the head store
    assign commit_data = entries[head].data;    // data in the head store


    // Store-to-load forwarding
    // Search from newest to oldest for matching address
    always_comb begin
        fwd_hit = 1'b0;
        fwd_data = 64'd0;
        
        // Search backwards from tail-1 to head
        for (int i = 15; i >= 0; i--) begin
            if (entries[i].valid && entries[i].addr_valid && entries[i].data_valid && 
                entries[i].addr == fwd_req_addr && entries[i].rob_idx < fwd_rob_idx && !fwd_hit) begin

                fwd_hit  = 1'b1;
                fwd_data = entries[i].data;
            end
        end
    end


    // Sequential logic
    always_ff @(posedge clk or posedge reset) begin
        
        if (reset) begin
            for (int i = 0; i < 16; i++) begin
                entries[i].valid <= 1'b0;
                head <= 4'd0;
                tail <= 4'd0;
                count <= 5'd0;
            end
        end
        
        else if (flush) begin
            for (int i = 0; i < 16; i++) begin
                if (entries[i].valid && entries[i].rob_idx >= flush_rob_idx) begin
                
                    entries[i].valid <= 1'b0;   // Kill any entry that came after the mispredicted branch
                end
            end
        end
        
        else begin
            // Dispatch - allocate new entry at tail
            if (dispatch_valid && !full) begin
                entries[tail].rob_idx <= dispatch_rob_idx;
                entries[tail].valid <= 1'b1;
                entries[tail].addr_valid <= 1'b0;
                entries[tail].data_valid <= 1'b0;
                entries[tail].addr <= 64'd0;
                entries[tail].data <= 64'd0;
                tail <= tail + 1;
                count <= count + 1;
            end

            // Address and data fill from execute stage
            if (write_valid) begin
                entries[write_sq_idx].addr <= write_addr;
                entries[write_sq_idx].data <= write_data;
                entries[write_sq_idx].addr_valid <= 1'b1;
                entries[write_sq_idx].data_valid <= 1'b1;
            end


            // Commit: drain head to cache
            if (commit_valid && commit_ready) begin
                entries[head].valid <= 1'b0;
                head  <= head + 1;
                count <= count - 1;
            end

            if (dispatch_valid && !full && commit_valid && commit_ready)
                count <= count;
        end
    end

endmodule