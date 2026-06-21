`timescale 1ps/1ps

module dcache (clk, reset, addr, write_data, mem_read, mem_write, read_data, ready, mem_read_req,
               mem_read_addr, mem_read_resp_valid, mem_read_resp_data, mem_write_req, mem_write_addr,
               mem_write_data, mem_write_done);
    input  logic clk;
    input  logic reset;

    // CPU side - MEM Stage
    input  logic [63:0] addr;
    input  logic [63:0] write_data;
    input  logic mem_read;
    input  logic mem_write;
    output logic [63:0] read_data;
    output logic ready;

    // Memory side — read channel
    output logic mem_read_req;
    output logic [63:0] mem_read_addr;
    input  logic mem_read_resp_valid;
    input  logic [255:0] mem_read_resp_data;

    // Memory side — write channel and dirty eviction
    output logic mem_write_req;
    output logic [63:0] mem_write_addr;
    output logic [255:0] mem_write_data;
    input  logic mem_write_done;


    // [63:12] tag (52 bits)
    // [11:5] index (7 bits - 2^7 lines)
    // [4:3] dword_sel (2 bits - 2^2 doublewords per block)
    // [2:0] byte_off (dword-aligned)
    logic [51:0] tag;
    logic [6:0]  index;
    logic [1:0]  dword_sel;

    assign tag = addr[63:12];
    assign index = addr[11:5];
    assign dword_sel = addr[4:3];

    // Storage
    logic [51:0] tag_array [0:127];
    logic [255:0] data_array [0:127];   // 256 bits = 4 × 64-bit dwords
    logic valid_array [0:127];
    logic  dirty_array [0:127];

    // Hit or not
    logic cache_hit;
    assign cache_hit = valid_array[index] && (tag_array[index] == tag);

    // Doubleword select
    logic [255:0] block_data;
    assign block_data = data_array[index];

    logic [63:0] selected_dword;
    always_comb begin
        case (dword_sel)
            2'd0: selected_dword = block_data[63:0];
            2'd1: selected_dword = block_data[127:64];
            2'd2: selected_dword = block_data[191:128];
            2'd3: selected_dword = block_data[255:192];
        endcase
    end

    // FSM
    typedef enum logic [2:0] {
        IDLE,
        WRITEBACK,
        WB_WAIT,
        REQUEST,
        WAIT,
        FILL,
        REPLAY
    } state_t;

    state_t state, next_state;

    // Is victim dirty - need writeback before we can fill
    logic victim_dirty;
    assign victim_dirty = valid_array[index] && dirty_array[index];

    // Is there an access happening
    logic accessing;
    assign accessing = mem_read || mem_write;

    // State register
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next state logic
    always_comb begin
        next_state = state;
        case (state)
            
            IDLE: begin
                if (accessing && !cache_hit) begin
                    if (victim_dirty)
                        next_state = WRITEBACK;
                    else
                        next_state = REQUEST;
                end
            end
            
            WRITEBACK:  next_state = WB_WAIT;
            WB_WAIT: begin
                if (mem_write_done)
                    next_state = REQUEST;
            end
            
            REQUEST:    next_state = WAIT;
            WAIT: begin
                if (mem_read_resp_valid)
                    next_state = FILL;
            end
            
            FILL:       next_state = REPLAY;
            
            REPLAY:     next_state = IDLE;
            
            default:    next_state = IDLE;
        endcase
    end

    // Output logic
    assign read_data = selected_dword;
    assign ready = (state == IDLE && (!accessing || cache_hit)) || (state == REPLAY);

    // Memory read request (fetch new block)
    assign mem_read_req  = (state == REQUEST);
    assign mem_read_addr = {addr[63:5], 5'b0};   // block-aligned

    // Memory write request (evict dirty victim)
    assign mem_write_req  = (state == WRITEBACK);
    assign mem_write_addr = {tag_array[index], index, 5'b0};  // victim's address
    assign mem_write_data = data_array[index];                // victim's data

    // Cache fill 
    always_ff @(posedge clk) begin
        if (state == FILL) begin
            data_array[index] <= mem_read_resp_data;
            tag_array[index] <= tag;
            valid_array[index] <= 1'b1;
            dirty_array[index] <= 1'b0;   // fresh from memory, not dirty
        end
    end

    // Write hit - update cache + set dirty
    always_ff @(posedge clk) begin
        if ((state == IDLE || state == REPLAY) && cache_hit && mem_write) begin
            case (dword_sel)
                2'd0: data_array[index][63:0]    <= write_data;
                2'd1: data_array[index][127:64]  <= write_data;
                2'd2: data_array[index][191:128] <= write_data;
                2'd3: data_array[index][255:192] <= write_data;
            endcase
            
            dirty_array[index] <= 1'b1;
        end
    end

    // Init
    integer i;
    initial begin
        for (i = 0; i < 128; i++) begin
            valid_array[i] = 1'b0;
            dirty_array[i] = 1'b0;
        end
    end

endmodule