`timescale 1ps/1ps

module mux2to1 (out, in0, in1, sel);
	output logic out; 
	input logic in0, in1, sel;
	
	logic notSel, w0, w1;
	
	not #50 n1(notSel, sel);
	and #50 a1(w0, in0, notSel);   // select in0
	and #50 a2(w1, in1, sel);		 // select in1
	or #50 o1(out, w0, w1);        // combine both
	

endmodule
