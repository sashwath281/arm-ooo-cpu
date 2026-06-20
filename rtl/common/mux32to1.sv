`timescale 1ps/1ps

module mux32to1(out, in, sel);
	output logic out; 
	input logic [31:0] in;
	input logic [4:0] sel;
	
	// 32 to 1
	logic [15:0] s1;
	logic [7:0] s2;
	logic [3:0] s3;
	logic [1:0] s4;
	
	genvar i;
	
	// Stage 1: 32 to 16.
	generate
		for(i = 0; i<16; i = i+1) begin: stage1
			mux2to1 m(.out(s1[i]), .in0(in[2*i]), .in1(in[2*i+1]), .sel(sel[0]));
		end 
	
	endgenerate
	
	
	// Stage 2: 16 to 8.
	generate
		for(i = 0; i<8; i = i+1) begin: stage2
			mux2to1 m(.out(s2[i]), .in0(s1[2*i]), .in1(s1[2*i+1]), .sel(sel[1]));
		end 
	
	endgenerate
	
	
	// Stage 3: 8 to 4.
	generate
		for(i = 0; i<4; i = i+1) begin: stage3
			mux2to1 m(.out(s3[i]), .in0(s2[2*i]), .in1(s2[2*i+1]), .sel(sel[2]));
		end 
	
	endgenerate
	
	
	// Stage 4: 4 to 2.
	generate
		for(i = 0; i<2; i = i+1) begin: stage4
			mux2to1 m(.out(s4[i]), .in0(s3[2*i]), .in1(s3[2*i+1]), .sel(sel[3]));
		end 
	
	endgenerate
	
	// Stage 5: 2 to 1.
	mux2to1 finalM (.out(out), .in0(s4[0]), .in1(s4[1]), .sel(sel[4]));


endmodule

