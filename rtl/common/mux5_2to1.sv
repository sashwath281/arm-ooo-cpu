`timescale 1ps/1ps

module mux5_2to1 (out, a, b, sel);
    output logic [4:0] out;
    input  logic [4:0] a, b;
    input  logic sel;
    
    genvar i;

    generate
        for (i = 0; i < 5; i++) begin: mux_loop
            mux2to1 m(.out(out[i]), .in0(a[i]), .in1(b[i]), .sel(sel));

        end
    endgenerate

endmodule