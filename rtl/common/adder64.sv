`timescale 1ps/1ps

module adder64(sum, cout, carry, a, b, cin);
	input logic [63:0] a, b;
	input logic cin;
	output logic [63:0] sum;
	output logic cout;
	output logic [63:0] carry;
	

	genvar i;

	full_adder fa(.sum(sum[0]), .cout(carry[0]), .a(a[0]), .b(b[0]), .cin(cin));

	generate 
		for (i = 1; i<64; i = i + 1) begin: adderLoop
			full_adder fa(.sum(sum[i]), .cout(carry[i]), .a(a[i]), .b(b[i]), .cin(carry[i-1]));
		end
	endgenerate
	
	assign cout = carry[63]; // carry out

endmodule