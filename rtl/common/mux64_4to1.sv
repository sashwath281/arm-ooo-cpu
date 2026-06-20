`timescale 1ps/1ps

module mux64_4to1 (out, a, b, c, d, sel);

    output logic [63:0] out;
    input  logic [63:0] a, b, c, d;
    input  logic [1:0] sel;

    genvar i;

    generate
        for (i = 0; i < 64; i++) begin : muxes

            mux4to1 m (
                .out(out[i]),
                .a(a[i]),
                .b(b[i]),
                .c(c[i]),
                .d(d[i]),
                .sel(sel)
            );

        end
    endgenerate

endmodule