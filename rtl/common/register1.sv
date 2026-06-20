`timescale 1ps/1ps

module register1 (q, d, writeEnable, clk, reset);
	output logic q;
	input logic d;
	input logic clk, reset, writeEnable;
	
	// drives d-input of flip-flops. 
	logic dIn, notEn, load, hold; 
			
	not #50 n1(notEn, writeEnable); 
	and #50 a1(load, writeEnable, d); 
	and #50 a2(hold, notEn, q);
	or #50 o1(dIn, load, hold);	
			
	// Each bit now stored in one flip-flop.
	D_FF d_ff(.q(q), .d(dIn), .reset(reset), .clk(clk));
		
	
endmodule