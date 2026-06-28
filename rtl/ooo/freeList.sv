`timescale 1ps/1ps

module free_list(clk, reset, allocate_req, allocate_preg, empty, free_valid, free_preg);
    input logic clk;
    input logic reset;

    // Allocate interface (rename stage pops one)
    input logic allocate_req;
    output logic [5:0] allocate_preg;      // physical reg number given out
    output logic empty;                 // stall rename if empty

    // Free interface (commit stage pushes one back)
    input logic free_valid;
    input logic [5:0] free_preg;       // physical reg returned


    // 32 physical regs available (P32–P63)
    // P0–P31 start mapped to X0–X31, not in the free list
    logic [5:0] fifo [0:31];
    logic [4:0] head, tail;
    logic [5:0] count;

    assign empty = (count == 0);
    assign allocate_preg = fifo[head];

    always_ff @(posedge clk or posedge reset) begin
        
        if (reset) begin
            // Fill with P32–P63
            for (int i = 0; i < 32; i++)
                fifo[i] <= 6'(i + 32);
                head  <= 5'd0;
                tail  <= 5'd0;
                count <= 6'd32;
        end

        else begin
            // Simultaneous alloc + free
            if (allocate_req && !empty && free_valid) begin
                fifo[head] <= fifo[head];  // head moves
                head       <= head + 1;
                fifo[tail] <= free_preg;
                tail       <= tail + 1;
                // count stays the same (one in, one out)
            end

            // Alloc only
            else if (allocate_req && !empty) begin
                head  <= head + 1;
                count <= count - 1;
            end

            // Free only
            else if (free_valid) begin
                fifo[tail] <= free_preg;
                tail       <= tail + 1;
                count      <= count + 1;
            end
        end
    end

endmodule