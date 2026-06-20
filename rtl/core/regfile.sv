`timescale 1ps/1ps

module regfile(ReadData1, ReadData2, WriteData, ReadRegister1, ReadRegister2, WriteRegister,
						  RegWrite, clk);
	output logic [63:0] ReadData1, ReadData2;
	input logic [63:0] WriteData;
	input logic [4:0] ReadRegister1, ReadRegister2, WriteRegister;
	input logic RegWrite, clk;
	
	// Internal storage - 32 registers each having 64 bits. 
	logic [31:0][63:0] registerOut ;
	
	// Decoder output
	logic [31:0] decoderOut;
	
	// 5to32 decoder selects which register to write to only when RegWrite is 1. 
	decoder5to32 dec(.out(decoderOut), .in(WriteRegister), .enable(RegWrite));
	
	genvar i;
	
	// Making 31 registers as the last one is always 0. 
	generate
		for(i = 0; i < 31; i++) begin: registers
			register64 r64(.clk(clk), .q(registerOut[i]), .d(WriteData), .writeEnable(decoderOut[i]));
		end 
	endgenerate

		
	assign registerOut[31] = 64'b0; // register 31 is always 0.
	
	
	// Muxes to read two registers independently.
	mux32to1_64 mux1(.out(ReadData1), .in(registerOut), .sel(ReadRegister1));
	mux32to1_64 mux2(.out(ReadData2), .in(registerOut), .sel(ReadRegister2));


endmodule
		