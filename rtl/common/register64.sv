`timescale 1ps/1ps

module register64(q,d,writeEnable, clk);
	output logic [63:0] q;
	input logic [63:0] d;
	input logic clk, writeEnable;
	
	// drives d-input of flip-flops. 
	logic [63:0] dIn;
	
	genvar i; 
	
	generate
		for(i = 0; i < 64; i++) begin: bits
			
			logic notEn, load, hold; 
			
			not #50 n1(notEn, writeEnable);      // invert enable
			and #50 a1(load, writeEnable, d[i]); // select new data
			and #50 a2(hold, notEn, q[i]);		 // hold the old value
			or #50 o1(dIn[i], load, hold);		 // final mux output
			
			// Each bit now stored in one flip-flop.
			D_FF d_ff(.q(q[i]), .d(dIn[i]), .reset(1'b0), .clk(clk));
			
		end
	endgenerate
	

	
endmodule
