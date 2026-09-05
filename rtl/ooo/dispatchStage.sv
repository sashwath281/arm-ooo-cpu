`timescale 1ps/1ps

module dispatchStage (
    input logic clk,
    input logic reset,

    // From rename stage
    input logic rename_valid,                   // valid instruction
    input logic [5:0] rename_source1,           // physical register 1
    input logic [5:0] rename_source2,           // physical register 2
    input logic [5:0] rename_dest,              // the phys reg free list gives us.
    input logic [5:0] rename_old,               // the phys reg the arch dest used to point to.
    input logic rename_source1_ready,           // status of source 1
    input logic rename_source2_ready,           // status of source 2
    input logic [63:0] rename_pc,               // All the control signals, if branches, if destinations, etc
    input logic [1:0] rename_alu_op,
    input logic rename_branch,
    input logic rename_load,
    input logic rename_store,
    input logic [4:0] rename_arch_dest,
    input logic [63:0] rename_immediate,
    input logic rename_imm,
    input logic rename_uncondBranch,
    input logic rename_condBranch,
    input logic [63:0] rename_branchTarget,
    input logic rename_branch_cbz,
    input logic rename_predictedTaken,
    input logic [63:0] rename_predictedTarget,
    input logic rename_flagSet,
    input logic rename_branchReg,


    // Stall
    output logic stall,                         // from rename stage

    // To ROB
    output logic rob_dispatch_valid,            // install this instruction in the ROB
    output logic [4:0] rob_arch_dest,           // Fields the ROB stores per entry
    output logic [5:0] rob_dest,
    output logic [5:0] rob_old,
    output logic [63:0] rob_pc,
    output logic rob_branch,
    output logic rob_store,
    input logic [4:0] rob_idx,                  // input from ROB - slot number
    input logic rob_full,                       // input - completely full, can't accept

    // To Issue Queue
    output logic iq_dispatch_valid,             // Everything the IQ needs to hold
    output logic [5:0] iq_dest,                 // the instruction while it waits for operands
    output logic [5:0] iq_source1,
    output logic [5:0] iq_source2,
    output logic iq_source1_ready,
    output logic iq_source2_ready,
    output logic [4:0] iq_rob_idx,
    output logic [1:0] iq_alu_op,
    output logic iq_load,
    output logic iq_store,
    input  logic iq_full,
    output logic [63:0] iq_immediate,
    output logic iq_imm,
    output logic iq_uncondBranch,
    output logic iq_condBranch,
    output logic [63:0] iq_branchTarget,
    output logic iq_branch_cbz,
    output logic [63:0] iq_pc,
    output logic iq_predictedTaken,
    output logic [63:0] iq_predictedTarget,
    output logic iq_flagSet,
    output logic iq_branchReg,

    // To Store Queue (only for stores)
    output logic sq_dispatch_valid,             // is it a store?
    input logic sq_full,                        // is it full?

    // To Load Queue (only for loads)
    output logic lq_dispatch_valid,             // is it a load?
    input logic lq_full,                        // is it ful?

    // Checkpoint trigger (for branches)
    output logic checkpoint_valid,              // Trigger and ID for the RAT snapshot in the rename stage.
    output logic [4:0] checkpoint_id,            // Fires on branches.

    // Flush
    input logic flush);


    
    logic can_dispatch;                         // Can we dispatch this cycle?

    assign can_dispatch = rename_valid && !flush && !rob_full && !iq_full &&
                          (!rename_store || !sq_full) &&
                          (!rename_load  || !lq_full);

    assign stall = rename_valid && !can_dispatch;


    // ROB
    assign rob_dispatch_valid = can_dispatch;     // fires when all 5 dispatch conditions hold
    assign rob_arch_dest = rename_arch_dest;      // same as before
    assign rob_dest = rename_dest;
    assign rob_old = rename_old;
    assign rob_pc = rename_pc;                    // for exception/mispredict handling
    assign rob_branch = rename_branch;            // branches need prediction check
    assign rob_store = rename_store;              // stores need a SQ drain. 


    // Issue Queue
    assign iq_dispatch_valid = can_dispatch;            // fires when all 5 dispatch conditions hold
    assign iq_dest = rename_dest;                       // same as before
    assign iq_source1 = rename_source1;
    assign iq_source2 = rename_source2;
    assign iq_source1_ready = rename_source1_ready;
    assign iq_source2_ready = rename_source2_ready;
    assign iq_rob_idx = rob_idx;                        // the ROBs output is fed straight into tyhe input of IQ
    assign iq_alu_op = rename_alu_op;
    assign iq_load = rename_load;
    assign iq_store = rename_store;
    assign iq_immediate = rename_immediate;
    assign iq_imm = rename_imm;
    assign iq_uncondBranch = rename_uncondBranch;
    assign iq_condBranch = rename_condBranch;
    assign iq_branchTarget = rename_branchTarget;
    assign iq_branch_cbz = rename_branch_cbz;
    assign iq_pc = rename_pc;
    assign iq_predictedTaken = rename_predictedTaken;
    assign iq_predictedTarget = rename_predictedTarget;
    assign iq_flagSet = rename_flagSet;
    assign iq_branchReg = rename_branchReg;


    // Store Queue
    assign sq_dispatch_valid = can_dispatch && rename_store;        // 5 conditions are met and isntruction is a store


    // Load Queue
    assign lq_dispatch_valid = can_dispatch && rename_load;         // 5 conditions are met and isntruction is a load


    // Branch Checkpoint
    assign checkpoint_valid = can_dispatch && rename_branch;        // 5 conditions are met and instruction is a branch
    assign checkpoint_id = rob_idx;                                 // use ROB slot the branch is going into as checkpoint ID


endmodule