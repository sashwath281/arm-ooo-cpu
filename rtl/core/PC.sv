`timescale 1ps/1ps

module PC (clk, reset, writeEnable, next_pc, pc);
    input  logic clk, reset, writeEnable;
    input  logic [63:0] next_pc;
    output logic [63:0] pc;

    logic [63:0] dIn;

    genvar i;
    generate
        for (i = 0; i < 64; i++) begin: loop
            logic notEn, load, hold;
            not #50 n1 (notEn, writeEnable);
            and #50 a1 (load, writeEnable, next_pc[i]);
            and #50 a2 (hold, notEn, pc[i]);
            or  #50 o1 (dIn[i], load, hold);
            D_FF dff (.q(pc[i]), .d(dIn[i]), .reset(reset), .clk(clk));
        end
    endgenerate
    
endmodule
