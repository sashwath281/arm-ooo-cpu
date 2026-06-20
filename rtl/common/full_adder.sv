`timescale 1ps/1ps

module full_adder(sum, cout, a, b, cin);
	input a, b, cin;
	output sum, cout;
	
	logic w1, w2, w3;
	
	// sum = 1 if a xor b xor cin is 1
	xor #(50) gate1(w1, a, b);
	xor #(50) gate2(sum, w1, cin);
	
	//cout = 1 if a dn b or a and c in or b and cin
	and #(50) gate3(w2, a, b);
    and #(50) gate4(w3, w1, cin);  // using (a XOR b) & cin
    or  #(50) gate5(cout, w2, w3);
	
endmodule
