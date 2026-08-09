`timescale 1ps/1ps

module decoder2to4(out, in, enable);
	// 2 to 4 decoder that decides which 3 to 8 decoder must be selected
    output logic [3:0] out;
    input  logic [1:0] in;
    input  logic enable;

    logic nin0, nin1;

    not #(50) n0(nin0, in[0]);
    not #(50) n1(nin1, in[1]);

    and #(50) a0(out[0], enable, nin1, nin0);
    and #(50) a1(out[1], enable, nin1, in[0]);
    and #(50) a2(out[2], enable, in[1], nin0);
    and #(50) a3(out[3], enable, in[1], in[0]);
endmodule
