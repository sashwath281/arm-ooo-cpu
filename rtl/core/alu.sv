`timescale 1ps/1ps

module alu (A, B, cntrl, result, negative, zero, overflow, carry_out);
    input logic [63:0] A, B;
    input logic [2:0] cntrl;
    output logic [63:0] result;

    output logic negative, zero, overflow, carry_out;

    logic [63:0] adderOut;  // output of adder
    logic adderCout;
    logic [63:0] bAS;       // b for either ADD (B) or SUB(~B)
    logic sub;              // 1 for SUB(011) only
    logic isAddSub;         // 1 for ADD(010) or SUB(011)
    logic not_cntrl2;       // ~cntrl[2] 
    logic overflow1;        // the overflow before we gate it. 
    logic [63:0] adderCarry; // carry chain for overflow
    
    logic [63:0] ANDOut;    // output of and64
    logic [63:0] OROut;     // output of or64
    logic [63:0] XOROut;    // output of xor64



    // Detect ADD or SUB. 
    not #(50) gate1(not_cntrl2, cntrl[2]);
    and #(50) gate2(isAddSub, not_cntrl2, cntrl[1]);
    and #(50) gate3(sub, isAddSub, cntrl[0]);


    // invert b for subtration using xorInverter module
    xorInverter xI(.out(bAS), .b(B), .subtract(sub));

    // single adder which does both ADD and SUBTRACT.
    adder64 adder(.sum(adderOut), .cout(adderCout), .carry(adderCarry), .a(A), .b(bAS), .cin(sub));


    //Operators
    and64 AND(.out(ANDOut), .a(A), .b(B));
    or64 OR(.out(OROut), .a(A), .b(B));
    xor64 XOR(.out(XOROut), .a(A), .b(B));


    // Select correct result
    aluMux mux(.result(result), .addsub(adderOut), .andIn(ANDOut), .orIn(OROut), .xorIn(XOROut),
               .B(B), .cntrl(cntrl));
	 
	 
	// If the top bit is 1, negative
	assign negative = result[63];


    // Zero detect
	zeroDetect64 zd(.zero(zero), .in(result));
	 

    // Carry out is only valid for 010 and 011. 
	mux2to1 carrymux(.out(carry_out), .in0(1'b0), .in1(adderCout), .sel(isAddSub));
	

    // Overflow is only valid for ADD and SUB
    overflowDetect oDetect (.overflow(overflow1), .carryInMSB(adderCarry[62]),
                            .carryOutMSB(adderCarry[63]));

    // Overflow = 0 for every other operation
    and #(50) overflowF(overflow, overflow1, isAddSub);


endmodule

