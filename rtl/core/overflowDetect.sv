`timescale 1ps/1ps

module overflowDetect(overflow, carryInMSB, carryOutMSB);
    input logic carryInMSB;
    input logic carryOutMSB; 
    output logic overflow; 

    xor #(50) g1(overflow, carryInMSB,carryOutMSB);


endmodule