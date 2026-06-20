`timescale 1ps/1ps

module aluMux(result, addsub, andIn, orIn, xorIn, B, cntrl);
    input  [63:0] addsub, andIn, orIn, xorIn, B;
    input  [2:0]  cntrl;
    output [63:0] result;

    logic [63:0] andOr;
    logic [63:0] operators; 
    logic [63:0] main;


    // select AND or OR based on cntrl[0]
    mux64_2to1 mux1(.out(andOr), .a(andIn), .b(orIn), .sel(cntrl[0]));


    // select AND/OR or XOR based on cntrl[1]
    mux64_2to1 mux2(.out(operators), .a(andOr), .b(xorIn), .sel(cntrl[1]));


    // select addsub or operators based on cntrl[2]
    mux64_2to1 mux3(.out(main), .a(addsub), .b(operators), .sel(cntrl[2]));


    // Passing B directly only if cntrl=000.
    logic not_c0, not_c1, not_c2, temp, passB;
    not #(50) g1(not_c0, cntrl[0]);
    not #(50) g2(not_c1, cntrl[1]);
    not #(50) g3(not_c2, cntrl[2]);
    and #(50) g4(temp, not_c2, not_c1);
    and #(50) g5(passB, temp, not_c0);


    // select B or the computed result. 
    mux64_2to1 mux4(.out(result), .a(main), .b(B), .sel(passB));
    


endmodule
    