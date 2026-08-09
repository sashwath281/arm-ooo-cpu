`timescale 1ps/1ps

module renameStage (
    input logic clk,
    input logic reset,

    // From decode stage
    input logic decode_valid,                   // pulse if decode has a valid instruction
    input logic [4:0] decode_arch_source1,      // source 1 arch reg number
    input logic [4:0] decode_arch_source2,      // source 2 arch reg number
    input logic [4:0] decode_arch_dest,         // destination arch reg number
    input logic decode_has_dest,                // some instructions don't write (stores, branches)
    input logic [63:0] decode_pc,               // PC of the instruction being renamed
    input logic [1:0] decode_alu_op,            // ALU operation for the instruction
    input logic decode_branch,                  // is this instruction a branch?
    input logic decode_load,                    // is this instruction a load?
    input logic decode_store,                   // is this instruction a store?
    input logic [63:0] decode_immediate,        // immediate value for the instruction
    input logic decode_imm,                 // does this instruction use the immediate value?
    input logic decode_uncondBranch,            // is this instruction an unconditional branch?
    input logic decode_condBranch,              // is this instruction a conditional branch?
    input logic [63:0] decode_branchTarget,     // target address for the branch instruction
    input logic decode_branch_cbz,              // is this instruction a CBZ instruction?


    // To dispatch (renamed instruction)
    output logic rename_valid,                  // pulse if rename has a valid instruction
    output logic [5:0] rename_source1,             // source 1 physical reg number
    output logic [5:0] rename_source2,             // source 2 physical reg number
    output logic [5:0] rename_dest,             // destination physical reg number
    output logic [5:0] rename_old,              // for ROB to free at commit
    output logic rename_source1_ready,             // is source 1 ready (not busy)
    output logic rename_source2_ready,             // is source 2 ready (not busy)
    output logic [63:0] rename_pc,              // PC of the instruction being renamed
    output logic [1:0] rename_alu_op,           // ALU operation for the instruction
    output logic rename_branch,                 // is this instruction a branch?
    output logic rename_load,                   // is this instruction a load?
    output logic rename_store,                  // is this instruction a store?
    output logic [4:0] rename_arch_dest,        // destination arch reg number
    output logic [63:0] rename_immediate,       // immediate value for the instruction
    output logic rename_imm,                    // does this instruction use the immediate value?
    output logic rename_uncondBranch,           // is this instruction an unconditional branch?
    output logic rename_condBranch,             // is this instruction a conditional branch?
    output logic [63:0] rename_branchTarget,    // target address for the branch instruction
    output logic rename_branch_cbz,             // is this instruction a CBZ instruction?

    // Stall
    output logic stall,                         // pulse if rename cannot accept a new instruction (free list empty)

    // From commit (free old physical register)
    input logic commit_free_valid,              // pulse if commit is freeing an old physical register
    input logic [5:0] commit_free_preg,         // which physical register is being freed

    // From CDB (clear busy bit)    
    input logic cdb_valid,                      // pulse if an instruction just wrote back to this phys reg
    input logic [5:0] cdb_phys_dest,            // which physical register is being written to

    // Checkpoint (for branch recovery)
    input logic checkpoint_valid,               // pulse if a branch is entering the pipeline (snap the RAT)
    input logic [4:0] checkpoint_id,            // save the RAT snapshot under this ID

    // Restore (on misprediction)
    input logic restore_valid,                  // pulse if a branch mispredicted (restore the RAT)
    input logic [4:0] restore_id,               // restore the RAT from this saved snapshot

    // Flush (from Recovery)
    input logic flush);                         // Wipe the current state - feeds into free list and busy table reset      


    // Free List
    logic [5:0] provide_reg;
    logic free_list_empty;

    freeList fl (.clk(clk), .reset(reset || flush), .provide_req(decode_valid && decode_has_dest && !free_list_empty),
                  .provide_reg_num(provide_reg), .empty(free_list_empty), .old_reg(commit_free_valid),
                  .old_reg_num(commit_free_preg));


    // RAT
    logic [5:0] rat_preg1, rat_preg2, rat_old;

    rat rat_inst (.clk(clk), .reset(reset), .read_reg1(decode_arch_source1), .read_reg2(decode_arch_source2),
                  .read_preg1(rat_preg1), .read_preg2(rat_preg2), .write_valid(decode_valid && decode_has_dest && !stall),
                  .write_reg(decode_arch_dest), .write_preg_old(rat_old), .write_preg_new(provide_reg),
                  .checkpoint_valid(checkpoint_valid), .checkpoint_id(checkpoint_id), .restore_valid(restore_valid || flush),
                  .restore_id(restore_id));


    // Busy Table
    logic busy1, busy2;

    busyTable bt (.clk(clk), .reset(reset || flush), .set_valid(decode_valid && decode_has_dest && !stall),
                   .set_preg(provide_reg), .clear_valid(cdb_valid), .clear_preg(cdb_phys_dest),
                   .read_preg1(rat_preg1), .read_preg2(rat_preg2), .busy1(busy1), .busy2(busy2));


    // Stall
    assign stall = decode_valid && decode_has_dest && free_list_empty;

    
    // Outputs
    assign rename_valid = decode_valid && !stall;                   // instruction is valid if its real and passing through the cycle and not stalled. 
    assign rename_source1 = rat_preg1;                         
    assign rename_source2 = rat_preg2;
    assign rename_dest = provide_reg;                           // the phys reg free list gives us. This instruction now owns this phys reg
    assign rename_old = rat_old;                               // the phys reg the arch dest used to point to. 
    assign rename_source1_ready = !busy1;                           // if busy1 = 1 (waiting), source1 is not ready and vice-versa
    assign rename_source2_ready = !busy2;                           // if busy2 = 1 (waiting), source2 is not ready and vice-versa
    assign rename_pc = decode_pc;                                   // Rest are just a rename of the input.
    assign rename_alu_op = decode_alu_op;                           // Tese carry through so dispatch can look at a single interface without needing to read from decode. 
    assign rename_branch = decode_branch;
    assign rename_load = decode_load;
    assign rename_store = decode_store;
    assign rename_arch_dest = decode_arch_dest;
    assign rename_immediate = decode_immediate;
    assign rename_imm = decode_imm;
    assign rename_uncondBranch = decode_uncondBranch;
    assign rename_condBranch = decode_condBranch;
    assign rename_branchTarget = decode_branchTarget;
    assign rename_branch_cbz = decode_branch_cbz;



endmodule