`timescale 1ps/1ps

module shiftLeft(in, out);
    input logic [63:0] in; 
    output logic [63:0] out; 


    // bit 0 and 1 are 0 due to left shift
    assign out[63:2] = in[61:0];
    assign out[1] = 1'b0; 
    assign out[0] = 1'b0; 


endmodule
