`timescale 1ps/1ps

module Control(instruction, ALUSrc, RegWrite, MemRead, MemWrite, Reg2Loc, ALUOp, MemToReg,
               BranchCond, BranchUncond, FlagSet, BranchReg, Link, ImmSel);

    input  logic [31:0] instruction;
    output logic ALUSrc;
    output logic RegWrite;    
    output logic MemRead;
    output logic MemWrite;
    output logic Reg2Loc;
    output logic [1:0]  ALUOp;
    output logic [1:0] ImmSel; 
    output logic MemToReg;
    output logic BranchCond;
    output logic BranchUncond;   
    output logic FlagSet;
    output logic BranchReg;   
    output logic Link;        

    logic [10:0] op11;  // R and D Type
    logic [9:0] op10;   // I Type
    logic [5:0] op6;    // B Type
    logic [7:0] op8;    // CB Type

    assign op11 = instruction[31:21];
    assign op10 = instruction[31:22];
    assign op6 = instruction[31:26];
    assign op8 = instruction[31:24];


    // ADD, SUB, LDUR, ADDI, BL
    assign RegWrite = (op11 == 11'b10101011000) | (op11 == 11'b11101011000)
                      | (op11 == 11'b11111000010)| (op10 == 10'b1001000100)
                      | (op6  == 6'b100101);


    // LDUR, STUR, ADDI.
    assign ALUSrc = (op11 == 11'b11111000010) | (op11 == 11'b11111000000)
                    | (op10 == 10'b1001000100);


    // LDUR
    assign MemRead = (op11 == 11'b11111000010);


    // STUR
    assign MemWrite = (op11 == 11'b11111000000);


    // LDUR
    assign MemToReg = (op11 == 11'b11111000010);


    // CBZ, STUR
    assign Reg2Loc = (op8  == 8'b10110100) | (op11 == 11'b11111000000);


    // B, BL, BR
    assign BranchUncond = (op6  == 6'b000101) | (op6  == 6'b100101)      
                          | (op11 == 11'b11010110000); 


    // CBZ, B.LT
    assign BranchCond = (op8  == 8'b10110100) | (op8  == 8'b01010100);


    // ADD, SUB
    assign FlagSet = (op11 == 11'b10101011000) | (op11 == 11'b11101011000);


    // BR
    assign BranchReg = (op11 == 11'b11010110000);


    // BL
    assign Link = (op6  == 6'b100101);


    // (ALUOp = 10) ADD, SUB
    assign ALUOp[1] = ((op11 == 11'b10101011000) | (op11 == 11'b11101011000)); 


    // (ALUOp = 01) B, BL, CBZ, B.LT 
    assign ALUOp[0] = (op6  == 6'b000101) | (op6  == 6'b100101) | (op8  == 8'b10110100)
                      | (op8  == 8'b01010100);

    // B/BL (10) and CBZ/B.LT (11)
    assign ImmSel[1] = (op6  == 6'b000101) | (op6  == 6'b100101) | (op8  == 8'b10110100)
                       | (op8  == 8'b01010100);

    // LDUR/STUR (01) and CBZ/B.LT (11)
    assign ImmSel[0] = (op11 == 11'b11111000010) | (op11 == 11'b11111000000) 
                       | (op8  == 8'b10110100) | (op8  == 8'b01010100);



endmodule
