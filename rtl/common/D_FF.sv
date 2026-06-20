`timescale 1ps/1ps

module D_FF(q, d, reset, clk);
	output reg q;
	input logic d, reset, clk;
	
	// State only updates on rising edge of the clock. 
	always_ff @(posedge clk)
		if(reset)
			q <= 0;  // On reset, set to 0
		else
			q <= d;  // Otherwise out = d

endmodule
