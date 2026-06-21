`timescale 1ps/1ps

module icache (clk, reset, pc, valid, instruction, ready, mem_req, mem_addr, mem_resp_valid, mem_resp_data);
    input logic clk;
    input logic reset;

    // CPU side (from fetch stage)
    input logic [63:0] pc;
    input logic valid;              // fetch is requesting

    // CPU side (to fetch stage)
    output logic [31:0] instruction;
    output logic ready;             // 1 = hit or replay, 0 = stall

    // Memory side (to/from backend)
    output logic mem_req;
    output logic [63:0] mem_addr;
    input  logic mem_resp_valid;
    input  logic [255:0] mem_resp_data;


    // [63:12] tag (52 bits)
    // [11:5] index (7 bits - 2^7 lines)
    // [4:2] word_sel (3 bits - 2^3 words per block)
    // [1:0] byte_off (word-aligned)
    logic [51:0] tag;
    logic [6:0]  index;
    logic [2:0]  word_sel;

    assign tag = pc[63:12];
    assign index = pc[11:5];
    assign word_sel = pc[4:2];

    // Storage
    logic [51:0] tag_array [0:127];
    logic [255:0] data_array [0:127];   // 256 bits = 8 × 32-bit words
    logic valid_array [0:127];

    // Hit or not
    logic cache_hit;
    assign cache_hit = valid_array[index] && (tag_array[index] == tag);

    // Word select from block
    logic [255:0] block_data;
    assign block_data = data_array[index];

    // Pick 1 of 8 words (32 bits each) based on word_sel
    logic [31:0] selected_word;
    
    always_comb begin
        case (word_sel)
            3'd0: selected_word = block_data[31:0];
            3'd1: selected_word = block_data[63:32];
            3'd2: selected_word = block_data[95:64];
            3'd3: selected_word = block_data[127:96];
            3'd4: selected_word = block_data[159:128];
            3'd5: selected_word = block_data[191:160];
            3'd6: selected_word = block_data[223:192];
            3'd7: selected_word = block_data[255:224];
        endcase
    end

    // FSM
    typedef enum logic [2:0] {
        IDLE,
        REQUEST,
        WAIT,
        FILL,
        REPLAY
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
            IDLE:    if (valid && !cache_hit) next_state = REQUEST;
            REQUEST: next_state = WAIT;
            WAIT:    if (mem_resp_valid)      next_state = FILL;
            FILL:    next_state = REPLAY;
            REPLAY:  next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Output
    assign instruction = selected_word;
    assign ready = (state == IDLE && cache_hit) || (state == REPLAY);
    assign mem_req = (state == REQUEST);
    assign mem_addr = {pc[63:5], 5'b0};   // block-aligned address

    // Cache fill on memory response
    always_ff @(posedge clk) begin
        if (state == FILL) begin
            data_array[index]  <= mem_resp_data;
            tag_array[index]   <= tag;
            valid_array[index] <= 1'b1;
        end
    end

    // init valid array
    integer i;
    initial begin
        for (i = 0; i < 128; i++)
            valid_array[i] = 1'b0;
    end

endmodule