`timescale 1ps/1ps

module mux32_2to1(a, b, sel, out);
	output logic [31:0] out;
	input logic [31:0] a, b;
	input logic sel;
	
	genvar i;
    generate
        for (i = 0; i < 32; i++) begin: bits
            mux2to1 m (.in0(a[i]), .in1(b[i]), .sel(sel), .out(out[i]));
        end
    endgenerate
    
endmodule

			