`timescale 1ps/1ps

module freeList(clk, reset, provide_req, provide_reg_num, empty, old_reg, old_reg_num);
    input logic clk;
    input logic reset;

    input logic provide_req;                   // provide a new physical register
    output logic [5:0] provide_reg_num;        // the physical register (X32-X63)
    output logic empty;                        // no physical registers left  

    input logic old_reg;                       // do we have a old reg to add back?
    input logic [5:0] old_reg_num;             // the old reg number

    // Storage
    logic [5:0] fifo [0:31];                   // the pool of physical registers
    logic [4:0] head, tail;                    // the 5-bit fifo pointers 
                                               // head is the slot to allocate to next while tail is the slot to add a free reg
    logic [5:0] count;                         // number of live physical regs. 


    assign empty = (count == 0);                // empty is no phys regs are live
    assign provide_reg_num = fifo[head];        // the reg at the top of the fifo pool.


    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            head <= 5'd0;                           // head points to 0 (start)
            tail <= 5'd0;                           // tail points to 0 (start)
            count <= 6'd32;                         // 32 physical regs left
        
            for(int i = 0; i < 32; i++)
                fifo[i] = 6'(i + 32);              // initialize the pool with X32-X63
        end

        else begin
            if (provide_req && !empty && old_reg) begin
                head <= head + 1;                   // move head to next reg
                fifo[tail] <= old_reg_num;          // add the old reg back to the bottom 
                tail <= tail + 1;                   // move tail to next reg
            end

            else if (provide_req && !empty) begin
                head <= head + 1;                   // move head to next reg
                count <= count - 1;                 // one less physical reg left
            end

            else if (old_reg) begin
                fifo[tail] <= old_reg_num;          // add back the old reg to the tail post. of fifo
                tail <= tail + 1;                   // move tail to next reg
                count <= count + 1;                 // one more physical reg left
            end
        end
    end

endmodule