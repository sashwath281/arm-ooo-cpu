`timescale 1ps/1ps

module decoder5to32(out, in, enable);
	output logic [31:0] out;
	input logic [4:0] in; 
	input logic enable;
	
	logic [3:0] upper_sel;
	decoder2to4 upper_decoder(
		.out(upper_sel),
		// use the upper 2 bits to choose which of the 3 to 8 decoders
		.in(in[4:3]),
		.enable(enable)
	);
	
	decoder3to8 dec0(
		.out(out[7:0]),
		//use the rest of bits to function in given 3 to 8 dec.
		.in(in[2:0]),
		//use upper sel as enable.
		.enable(upper_sel[0])
	);
	
	decoder3to8 dec1(
		.out(out[15:8]),
		//use the rest of bits to function in given 3to8 dec.
		.in(in[2:0]),
		//use upper sel as encoder
		.enable(upper_sel[1])
	);
	
	decoder3to8 dec2(
		.out(out[23:16]),
		//use the rest of bits to function in given 3to8 dec.
		.in(in[2:0]),
		//use upper sel as encoder
		.enable(upper_sel[2])
	);
	
	decoder3to8 dec3(
		.out(out[31:24]),
		//use the rest of bits to function in given 3to8 dec.
		.in(in[2:0]),
		//use upper sel as encoder
		.enable(upper_sel[3])
	);
endmodule
