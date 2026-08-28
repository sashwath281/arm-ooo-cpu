`timescale 1ps/1ps

module commitStage (
    input logic clk,
    input logic reset,

    // From ROB
    input logic rob_commit_valid,
    input logic [4:0] rob_commit_arch_dest,
    input logic [5:0] rob_commit_dest,
    input logic [5:0] rob_commit_old,
    input logic rob_commit_store,
    input logic rob_commit_branch,
    input logic [63:0] rob_commit_pc,

    // From ROB (flush)
    input logic rob_flush_valid,
    input logic [63:0] rob_flush_pc,

    // To free list (return old physical register)
    output logic free_valid,
    output logic [5:0] free_preg,

    // To store queue (drain store to D-Cache)
    output logic sq_commit_valid,

    // To fetch (redirect on flush)
    output logic flush,
    output logic [63:0] flush_redirect_pc,
    output logic flush_ack);


    // Free old physical register
    assign free_valid = rob_commit_valid && (rob_commit_old != 6'd0);
    assign free_preg = rob_commit_old;


    // Drain store
    assign sq_commit_valid = rob_commit_valid && rob_commit_store;


    // Flush handling
    assign flush = rob_flush_valid;
    assign flush_redirect_pc = rob_flush_pc;
    assign flush_ack = rob_flush_valid;         // immediate ack (single cycle)

endmodule