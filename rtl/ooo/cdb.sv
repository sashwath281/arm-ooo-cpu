`timescale 1ps/1ps

module cdb (clk, reset, ex_valid, ex_phys_dest, ex_result, ex_rob_idx, ex_branchTaken, ex_exception, cdb_valid,
            cdb_phys_dest, cdb_exception, cdb_result, cdb_rob_idx, cdb_branchTaken);
    input logic clk;
    input logic reset;

    // From execution unit
    input logic ex_valid;
    input logic [5:0] ex_phys_dest;
    input logic [63:0] ex_result;
    input logic [4:0] ex_rob_idx;
    input logic ex_branchTaken;
    input logic ex_exception;

    // Broadcast to everyone (directly wired, active this cycle)
    output logic cdb_valid;
    output logic [5:0] cdb_phys_dest;
    output logic [63:0] cdb_result;
    output logic [4:0] cdb_rob_idx;
    output logic cdb_branchTaken;
    output logic cdb_exception;


    // Pass-through and broadcast immediately
    assign cdb_valid = ex_valid && !reset;
    assign cdb_phys_dest = ex_phys_dest;
    assign cdb_result = ex_result;
    assign cdb_rob_idx = ex_rob_idx;
    assign cdb_branchTaken = ex_branchTaken;
    assign cdb_exception = ex_exception;

endmodule