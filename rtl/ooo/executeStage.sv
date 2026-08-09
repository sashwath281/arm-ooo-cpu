`timescale 1ps/1ps

module executeStage (
    input logic clk,
    input logic reset,

    // From issue queue
    input logic issue_valid,
    input logic [5:0] issue_dest,               // phys reg to write the result into (via CDB)
    input logic [5:0] issue_source1,            // phys reg numbers for source values
    input logic [5:0] issue_source2,
    input logic [4:0] issue_rob_idx,            // the identity tag for the instruction to the CDB and ROB
    input logic [1:0] issue_alu_op,             // 2-bit opcode
    input logic issue_load,                     // memory operation flags
    input logic issue_store,
    input logic [63:0] issue_immediate,         // the sign-extended constant
    input logic issue_imm,                      // 2nd source is immediate?
    input logic issue_uncondBranch,             // branch flags
    input logic issue_condBranch,               // branch flags
    input logic [63:0] issue_branchTarget,      // target addr for branch
    input logic issue_branch_cbz,               // is it CBZ or other branch

    // Physical reg file read ports
    output logic [5:0] read_phys_reg1,          // phys reg file address
    output logic [5:0] read_phys_reg2,          // phys reg file address
    input logic [63:0] read_data1,              // data in phys reg 1
    input logic [63:0] read_data2,              // data in phys reg 2

    // ALU result to CDB
    output logic ex_valid,                      // this cycle result is real
    output logic [5:0] ex_dest,                 // which phys reg the result goes 
    output logic [63:0] ex_result,              // the 64-bit ALU output
    output logic [4:0] ex_rob_idx,              // for ROB to mark the entry complete
    output logic ex_exception,                  // any faults?

    // To store queue (address and data for stores)
    output logic sq_write_valid,                // is a store?
    output logic [63:0] sq_write_addr,          // store addr
    output logic [63:0] sq_write_data,          // store data

    // To load queue (address for loads)
    output logic lq_exec_valid,                 // load?  
    output logic [63:0] lq_exec_addr,           // load addr

    // Branch resolution
    output logic branchResolved,                // a branch just executed
    output logic branch_actualTaken,            // the actual outcome
    output logic [63:0] branch_actualTarget,    // where the branch actually goes

    // Flush
    input logic flush);


    // Execute passes the phys reg numbers from the IQ straight to the PRF's read ports.
    assign read_phys_reg1 = issue_source1;
    assign read_phys_reg2 = issue_source2;


    // ALU
    logic [63:0] alu_result;
    logic alu_zero;
    logic alu_negative;

    // ALU operand B: register or immediate
    logic [63:0] alu_operand_b;
    assign alu_operand_b = issue_imm ? issue_immediate : read_data2;            // Mux to toggle issue_imm depending on 
                                                                                // whether second source is reg or imm
    always_comb begin
        alu_result = 64'd0;
        alu_zero = 1'b0;
        alu_negative = 1'b0;

        case (issue_alu_op)
            2'b00: alu_result = read_data1 + alu_operand_b;  // ADD/ADDI
            2'b01: alu_result = read_data1 - alu_operand_b;  // SUB/SUBI
            2'b10: alu_result = read_data1 & alu_operand_b;  // AND
            2'b11: alu_result = read_data1 | alu_operand_b;  // ORR
        endcase

        alu_zero = (alu_result == 64'd0);
        alu_negative = alu_result[63];
    end


    // Outputs

    // ALU result to CDB
    assign ex_valid = issue_valid && !issue_load && !issue_store && !flush;
    assign ex_dest = issue_dest;
    assign ex_result = alu_result;
    assign ex_rob_idx = issue_rob_idx;
    assign ex_exception = 1'b0;                     // no exceptions for now


    // Store: compute address (src1 and  immediate in src2)
    assign sq_write_valid = issue_valid && issue_store && !flush;
    assign sq_write_addr = alu_result;              // address = base + offset
    assign sq_write_data = read_data2;              // data to store


    // Load: compute address, send to LQ
    assign lq_exec_valid = issue_valid && issue_load && !flush;
    assign lq_exec_addr = alu_result;               // address = base + offset


    // Branch resolution
    logic branch;
    logic condTaken;

    assign branch = issue_uncondBranch || issue_condBranch;

    always_comb begin
        condTaken = 1'b0;
        if (issue_condBranch) begin
            if (issue_branch_cbz)
                condTaken = (read_data2 == 64'd0);        // CBZ: Rt is source2
            else
                condTaken = alu_negative;                 // B.LT: simplified
        end
    end

    assign branchResolved = issue_valid && branch && !flush;
    assign branch_actualTaken = issue_uncondBranch || condTaken;
    assign branch_actualTarget = issue_branchTarget;

endmodule