`timescale 1ps/1ps

module dcache (
    input logic clk,
    input logic reset,

    // CPU side (from LQ/SQ stage)
    input logic [63:0] addr,        // address from rename
    input logic valid,              // requesting
    input logic enable,             // 1 for store and 0 for load
    input logic [63:0] store_data,  // store data 

    output logic [63:0] load_data,  // LEGv8 loads are 64-b
    output logic ready,         
    output logic accept,   

    // Memory side (to/from backend)
    output logic mem_req,
    output logic mem_enable,            // tell the nackend this is a write-through
    output logic [63:0] mem_addr,   
    output logic [63:0] mem_write_data,  // data going to memory on a write-through
    input logic mem_resp_valid,
    input logic [255:0] mem_resp_data);

    // Latched address/enable/data - captured when a request is first accepted.
    logic [63:0] saved_addr;
    logic saved_enable;
    logic [63:0] saved_store_data;

    logic [51:0] saved_tag;
    logic [6:0] saved_index;
    logic [1:0] saved_dword_sel;


    // [63:12] tag (52 bits)
    // [11:5] index (7 bits - 2^7 lines)
    // [4:3] dword_sel (2 bits - 2^2 doublewords per block)
    // [2:0] byte offset within doubleword 
    logic [51:0] tag;
    logic [6:0] index;
    logic [1:0] dword_sel;

    assign tag = addr[63:12];
    assign index = addr[11:5];
    assign dword_sel = addr[4:3];

    assign saved_tag = saved_addr[63:12];
    assign saved_index = saved_addr[11:5];
    assign saved_dword_sel = saved_addr[4:3];

    // Storage
    logic [51:0] tag_array [0:127];
    logic [255:0] data_array [0:127]; 
    logic valid_array [0:127];

    // Hit or not
    logic cache_hit;
    assign cache_hit = valid_array[index] && (tag_array[index] == tag);

    // Word select from block
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

    assign load_data = selected_dword;

    // FSM
    typedef enum logic [2:0] {
        IDLE,
        REQUEST,
        WAIT,
        FILL,
        REPLAY, 
        WRITE_THROUGH, 
        MEM_WAIT
    } state_t;

    state_t state, next_state;


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
                if (valid && !enable && !cache_hit) 
                    next_state = REQUEST;           // load miss
                else if (valid && enable && !cache_hit)
                    next_state = REQUEST;           // store miss
                else if (valid && enable && cache_hit)
                    next_state = WRITE_THROUGH;     // store hit - push to memory
            end 

            REQUEST: next_state = WAIT;
            WAIT: if (mem_resp_valid)   next_state = FILL;
            FILL: next_state = REPLAY;

            REPLAY: begin
                if(saved_enable)
                    next_state = WRITE_THROUGH;
                else
                    next_state = IDLE; 
            end

            WRITE_THROUGH: next_state = MEM_WAIT; 
            MEM_WAIT: if(mem_resp_valid) next_state = IDLE; 
            
            default: next_state = IDLE;
        endcase
    end

    // Output
    assign ready = (state == IDLE && valid && !enable && cache_hit) || (state == REPLAY && !enable) || (state == MEM_WAIT && mem_resp_valid);
    assign mem_req = (state == REQUEST) || (state == WRITE_THROUGH);
    assign mem_addr = (state == WRITE_THROUGH) ? saved_addr : {saved_addr[63:5], 5'b0};   // block-aligned address
    assign mem_write_data = saved_store_data;     // only needed when mem_enable = 1
    assign mem_enable = (state == WRITE_THROUGH);
    assign accept = (state == IDLE && valid);

    // Cache fill on memory response
    integer i;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 128; i++)
                valid_array[i] <= 1'b0;
        end
        
        // Fill on memory response
        else if (state == FILL) begin
            data_array[saved_index] <= mem_resp_data;
            tag_array[saved_index] <= saved_tag;
            valid_array[saved_index] <= 1'b1;
        end

        // Write HIT at IDLE - update the relevant doubleword
        else if (state == IDLE && valid && enable && cache_hit) begin
            case(dword_sel)
                2'd0: data_array[index][63:0] <= store_data; 
                2'd1: data_array[index][127:64] <= store_data; 
                2'd2: data_array[index][191:128] <= store_data; 
                2'd3: data_array[index][255:192] <= store_data; 
            endcase
        end
    
        // write-allocate case - after REPLAY fills the block, apply the pending write
        else if (state == REPLAY && saved_enable) begin
            case(saved_dword_sel)
                2'd0: data_array[saved_index][63:0] <= saved_store_data; 
                2'd1: data_array[saved_index][127:64] <= saved_store_data; 
                2'd2: data_array[saved_index][191:128] <= saved_store_data; 
                2'd3: data_array[saved_index][255:192] <= saved_store_data; 
            endcase
        end
    end


    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            saved_addr <= 64'd0;
            saved_enable <= 1'b0;
            saved_store_data <= 64'd0;
        end
        else if (state == IDLE && valid) begin
            // capture on the cycle we're about to leave IDLE for a miss (load or store)
            saved_addr <= addr;
            saved_enable <= enable;
            saved_store_data <= store_data;
        end
    end


endmodule