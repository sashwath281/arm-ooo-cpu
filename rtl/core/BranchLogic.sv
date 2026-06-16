`timescale 1ps/1ps

module BranchLogic(instruction, BranchUncond, BranchCond, BranchReg, savedNegative,
                    savedOverflow, pc, branchImm, RegisterData1, RegisterData2, pcplus4, next_pc,
                    branch_taken);

    input  logic [31:0] instruction;
    input  logic BranchUncond, BranchCond, BranchReg;
    input  logic savedNegative, savedOverflow;
    input  logic [63:0] pc, branchImm, RegisterData1, RegisterData2, pcplus4;
    output logic [63:0] next_pc;
    output logic branch_taken;


    logic bltTaken, cbzZero, condResult, condTaken;
    logic [63:0] branchTarget;

    xor #(50) bltXOR(bltTaken, savedNegative, savedOverflow);
    
    zeroDetect64 cbz_zero(.zero(cbzZero), .in(RegisterData2));

    mux2to1 cond_mux(.out(condResult), .in0(cbzZero), .in1(bltTaken), .sel(instruction[30]));

    // takeBranch = BranchUncond OR (BranchCond AND condResult)
    and #(50) condAND(condTaken, BranchCond, condResult);
    or  #(50) takeOR(branch_taken, BranchUncond, condTaken);

    // BRanch Target
    logic [63:0] branchTargetAddr;
    logic branchAdder_cout;
    logic [63:0] branchAdder_carry;

    adder64 branchAdder (.sum(branchTargetAddr), .cout(branchAdder_cout),
                         .carry(branchAdder_carry), .a(pc), .b(branchImm),
                         .cin(1'b0));

    mux64_2to1 branchTarget_mux (.a(branchTargetAddr), .b(RegisterData1), 
                                 .sel(BranchReg), .out(branchTarget));

    mux64_2to1 pc_mux (.a(pcplus4), .b(branchTarget), .sel(branch_taken), .out(next_pc));


endmodule