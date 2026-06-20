`timescale 1ps/1ps

module decoder3to8(out, in, enable);
	 //3 to 8 decoder
    output logic [7:0] out;
    input  logic [2:0] in;
    input  logic enable;

    logic nin0, nin1, nin2;

    not #(50) n0(nin0, in[0]);
    not #(50) n1(nin1, in[1]);
    not #(50) n2(nin2, in[2]);

    and #(50) a0(out[0], enable, nin2, nin1, nin0);
    and #(50) a1(out[1], enable, nin2, nin1, in[0]);
    and #(50) a2(out[2], enable, nin2, in[1], nin0);
    and #(50) a3(out[3], enable, nin2, in[1], in[0]);
    and #(50) a4(out[4], enable, in[2], nin1, nin0);
    and #(50) a5(out[5], enable, in[2], nin1, in[0]);
    and #(50) a6(out[6], enable, in[2], in[1], nin0);
    and #(50) a7(out[7], enable, in[2], in[1], in[0]);
endmodule
