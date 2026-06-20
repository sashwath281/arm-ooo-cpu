`timescale 1ps/1ps

module WBForwardUnit (MEMWB_write_reg, MEMWB_RegWrite, read_reg1, read_reg2, ForwardWBA, ForwardWBB);
    input  logic [4:0] MEMWB_write_reg;
    input  logic MEMWB_RegWrite;
    input  logic [4:0] read_reg1;
    input  logic [4:0] read_reg2;
    output logic ForwardWBA;
    output logic ForwardWBB;


    logic not_xzr;
    logic eq1, eq2;
    logic regwriteAndNotxzr;

    // MEMWB_write_reg is not X31
    NotXZR5 xzr_check (
        .reg_num(MEMWB_write_reg),
        .not_xzr(not_xzr)
    );

    // MEMWB_write_reg matches read_reg1
    Equal5 cmp1 (
        .a(MEMWB_write_reg),
        .b(read_reg1),
        .eq(eq1)
    );

    // MEMWB_write_reg matches read_reg2
    Equal5 cmp2 (
        .a(MEMWB_write_reg),
        .b(read_reg2),
        .eq(eq2)
    );

    // MEMWB_RegWrite AND not X31
    and #50 and0 (regwriteAndNotxzr, MEMWB_RegWrite, not_xzr);
    and #50 and1 (ForwardWBA, regwriteAndNotxzr, eq1);
    and #50 and2 (ForwardWBB, regwriteAndNotxzr, eq2);


endmodule