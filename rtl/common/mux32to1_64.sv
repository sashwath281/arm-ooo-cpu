`timescale 1ps/1ps

module mux32to1_64(out, in, sel);
	output logic [63:0] out;
	input logic [31:0][63:0] in;
	input logic [4:0] sel;
	
	genvar i, j;
	
	generate
		for(i =0; i < 64; i = i+1) begin: bits
				
			logic [31:0] col;
			
			for(j = 0; j < 32; j = j+1) begin: register
				assign col[j] = in [j][i];
			end 
			
			// Select 1 of 32 bits. 
			mux32to1 m(.out(out[i]), .in(col), .sel(sel));
			
		end
	endgenerate
	

endmodule


			