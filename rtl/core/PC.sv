`timescale 1ps/1ps

module PC (clk, reset, next_pc, pc);
    input logic clk, reset;
    input logic [63:0] next_pc;
    output logic [63:0] pc;

    genvar i; 
    generate;
        for( i = 0; i < 64; i++) begin: loop
            D_FF dff (.q(pc[i]), .d(next_pc[i]), .reset(reset), .clk(clk));
        end
    endgenerate

endmodule
