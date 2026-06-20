`timescale 1ps/1ps

module zeroDetect64(zero, in);
	input logic [63:0] in;
	output logic zero;
	
	logic [15:0] lvl1;
	logic[3:0] lvl2;
	logic final_or;
	genvar i;
	
	generate
		for (i = 0; i < 16; i = i + 1) begin: loop1
			or #(50) g1(lvl1[i], in[4*i], in[4*i+1], in[4*i+2], in[4*i+3]);
        end
    endgenerate

    generate
        for (i = 0; i < 4; i = i + 1) begin: loop2
            or #(50) g2(lvl2[i], lvl1[4*i], lvl1[4*i+1], lvl1[4*i+2], lvl1[4*i+3]);
        end
    endgenerate

    or  #(50) g3(final_or, lvl2[0], lvl2[1], lvl2[2], lvl2[3]);
    not #(50) g4(zero, final_or);
endmodule