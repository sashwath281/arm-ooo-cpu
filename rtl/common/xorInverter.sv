`timescale 1ps/1ps

module xorInverter(out, b, subtract);
    input [63:0] b;
    input subtract;
    output [63:0] out;

    genvar i;

    generate
        for(i = 0; i < 64; i++) begin: xorInLoop

            xor #(50) gate1(out[i], b[i], subtract);
        end

    endgenerate


endmodule