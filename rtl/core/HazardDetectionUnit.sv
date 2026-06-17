`timescale 1ps/1ps

module HazardDetectionUnit (
    input  logic        IDEX_MemRead,
    input  logic [4:0]  IDEX_write_reg,
    input  logic [4:0]  IFID_read_reg1,
    input  logic [4:0]  IFID_read_reg2,
    input  logic        branch_taken,
    output logic        PCWrite,
    output logic        IFID_Write,
    output logic        ControlBubble,
    output logic        IFID_Flush
);

    logic eq_rs1, eq_rs2;
    logic any_match;
    logic load_use_hazard;
    logic not_hazard;

    // Does IDEX_write_reg match either source in IF/ID?
    Equal5 cmp_rs1 (.a(IDEX_write_reg), .b(IFID_read_reg1), .eq(eq_rs1));
    Equal5 cmp_rs2 (.a(IDEX_write_reg), .b(IFID_read_reg2), .eq(eq_rs2));

    // Either source matches → potential dependency
    or  #50 or_match  (any_match, eq_rs1, eq_rs2);

    // Load-use hazard: prior instr is a load AND a source matches
    and #50 hazard_and (load_use_hazard, IDEX_MemRead, any_match);

    // Stall: freeze PC + IF/ID, bubble the control going into ID/EX
    not #50 inv_hazard (not_hazard, load_use_hazard);

    buf #50 buf_pc    (PCWrite,       not_hazard);
    buf #50 buf_ifid  (IFID_Write,    not_hazard);
    buf #50 buf_bub   (ControlBubble, load_use_hazard);

    // Branch flush: kill whatever is in IF/ID right now
    buf #50 buf_flush (IFID_Flush, branch_taken);

endmodule