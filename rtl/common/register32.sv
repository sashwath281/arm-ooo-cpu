`timescale 1ps/1ps

module register32(q, d, writeEnable, clk, reset);
    output logic [31:0] q;
    input logic [31:0] d;
    input logic clk, writeEnable, reset;

    logic [31:0] dIn;

    genvar i;

    generate
        for(i = 0; i < 32; i++) begin: bits

            logic notEn, load, hold;

            not #50 n1(notEn, writeEnable);
            and #50 a1(load, writeEnable, d[i]);
            and #50 a2(hold, notEn, q[i]);
            or  #50 o1(dIn[i], load, hold);

            D_FF d_ff(.q(q[i]), .d(dIn[i]), .reset(reset), .clk(clk));

        end
    endgenerate

endmodule