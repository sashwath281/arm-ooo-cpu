`timescale 1ps/1ps

// Are a and b =
module Equal5 (
    input  logic [4:0] a,
    input  logic [4:0] b,
    output logic       eq
);

    logic x0, x1, x2, x3, x4;
    logic any_diff_0_3;
    logic any_diff;

    xor #50 xor0 (x0, a[0], b[0]);
    xor #50 xor1 (x1, a[1], b[1]);
    xor #50 xor2 (x2, a[2], b[2]);
    xor #50 xor3 (x3, a[3], b[3]);
    xor #50 xor4 (x4, a[4], b[4]);

    or  #50 or0  (any_diff_0_3, x0, x1, x2, x3);
    or  #50 or1  (any_diff, any_diff_0_3, x4);

    not #50 inv0 (eq, any_diff);

endmodule

// is register31 check
module NotXZR5 (
    input  logic [4:0] reg_num,
    output logic       not_xzr
);

    logic lower_four_are_one;
    logic is_xzr;

    and #50 and0 (lower_four_are_one,
                  reg_num[0],
                  reg_num[1],
                  reg_num[2],
                  reg_num[3]);

    and #50 and1 (is_xzr,
                  lower_four_are_one,
                  reg_num[4]);

    not #50 inv0 (not_xzr, is_xzr);

endmodule


module ForwardingUnit (
    input  logic [4:0] IDEX_read_reg1,
    input  logic [4:0] IDEX_read_reg2,

    input  logic [4:0] EXMEM_write_reg,
    input  logic       EXMEM_RegWrite,

    input  logic [4:0] MEMWB_write_reg,
    input  logic       MEMWB_RegWrite,

    output logic [1:0] ForwardA,
    output logic [1:0] ForwardB
);

    logic EXMEM_not_xzr;
    logic MEMWB_not_xzr;

    logic EXMEM_eq_A;
    logic EXMEM_eq_B;
    logic MEMWB_eq_A;
    logic MEMWB_eq_B;

    logic MEM_hazard_A_raw;
    logic MEM_hazard_B_raw;

    logic not_EX_hazard_A;
    logic not_EX_hazard_B;

    NotXZR5 check_EXMEM_xzr (
        .reg_num(EXMEM_write_reg),
        .not_xzr(EXMEM_not_xzr)
    );

    NotXZR5 check_MEMWB_xzr (
        .reg_num(MEMWB_write_reg),
        .not_xzr(MEMWB_not_xzr)
    );

    Equal5 exmem_compare_A (
        .a(EXMEM_write_reg),
        .b(IDEX_read_reg1),
        .eq(EXMEM_eq_A)
    );

    Equal5 exmem_compare_B (
        .a(EXMEM_write_reg),
        .b(IDEX_read_reg2),
        .eq(EXMEM_eq_B)
    );

    Equal5 memwb_compare_A (
        .a(MEMWB_write_reg),
        .b(IDEX_read_reg1),
        .eq(MEMWB_eq_A)
    );

    Equal5 memwb_compare_B (
        .a(MEMWB_write_reg),
        .b(IDEX_read_reg2),
        .eq(MEMWB_eq_B)
    );

    // EX/MEM hazard has priority.
    // ForwardA = 10 if EX/MEM should forward to ALU input A.
    and #50 ex_hazard_A (
        ForwardA[1],
        EXMEM_RegWrite,
        EXMEM_not_xzr,
        EXMEM_eq_A
    );

    // ForwardB = 10 if EX/MEM should forward to ALU input B.
    and #50 ex_hazard_B (
        ForwardB[1],
        EXMEM_RegWrite,
        EXMEM_not_xzr,
        EXMEM_eq_B
    );

    // Should Mem/WB forward if ex mem is not already?
    and #50 mem_hazard_A_raw_gate (
        MEM_hazard_A_raw,
        MEMWB_RegWrite,
        MEMWB_not_xzr,
        MEMWB_eq_A
    );

    and #50 mem_hazard_B_raw_gate (
        MEM_hazard_B_raw,
        MEMWB_RegWrite,
        MEMWB_not_xzr,
        MEMWB_eq_B
    );

    // MEM/WB forwarding only happens if EX/MEM is NOT already forwarding.
    not #50 inv_EX_hazard_A (
        not_EX_hazard_A,
        ForwardA[1]
    );

    not #50 inv_EX_hazard_B (
        not_EX_hazard_B,
        ForwardB[1]
    );

    // ForwardA = 01 if MEM/WB should forward to ALU input A.
    and #50 mem_hazard_A (
        ForwardA[0],
        MEM_hazard_A_raw,
        not_EX_hazard_A
    );

    // ForwardB = 01 if MEM/WB should forward to ALU input B.
    and #50 mem_hazard_B (
        ForwardB[0],
        MEM_hazard_B_raw,
        not_EX_hazard_B
    );

endmodule