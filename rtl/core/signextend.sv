`timescale 1ps/1ps

module signextend (
    input  logic [31:0] instruction,
    input  logic [1:0]  ImmSel,
    output logic [63:0] imm64
);

    logic [63:0] immI;
    logic [63:0] immD;
    logic [63:0] immB;
    logic [63:0] immCB;

    genvar i;

    // I-TYPE imm12

    assign immI[0]  = instruction[10];
    assign immI[1]  = instruction[11];
    assign immI[2]  = instruction[12];
    assign immI[3]  = instruction[13];
    assign immI[4]  = instruction[14];
    assign immI[5]  = instruction[15];
    assign immI[6]  = instruction[16];
    assign immI[7]  = instruction[17];
    assign immI[8]  = instruction[18];
    assign immI[9]  = instruction[19];
    assign immI[10] = instruction[20];
    assign immI[11] = instruction[21];

    generate
        for (i = 12; i < 64; i++) begin : I_SIGN
            assign immI[i] = 1'b0;
        end
    endgenerate

    // D-TYPE + R type ( R doesn't matter )

    assign immD[0] = instruction[12];
    assign immD[1] = instruction[13];
    assign immD[2] = instruction[14];
    assign immD[3] = instruction[15];
    assign immD[4] = instruction[16];
    assign immD[5] = instruction[17];
    assign immD[6] = instruction[18];
    assign immD[7] = instruction[19];
    assign immD[8] = instruction[20];

    generate
        for (i = 9; i < 64; i++) begin : D_SIGN
            assign immD[i] = instruction[20];
        end
    endgenerate

    // B-TYPE imm26

    generate
        for (i = 0; i < 26; i++) begin : B_LOW
            assign immB[i] = instruction[i];
        end

        for (i = 26; i < 64; i++) begin : B_SIGN
            assign immB[i] = instruction[25];
        end
    endgenerate

    // CB-TYPE imm19

    assign immCB[0]  = instruction[5];
    assign immCB[1]  = instruction[6];
    assign immCB[2]  = instruction[7];
    assign immCB[3]  = instruction[8];
    assign immCB[4]  = instruction[9];
    assign immCB[5]  = instruction[10];
    assign immCB[6]  = instruction[11];
    assign immCB[7]  = instruction[12];
    assign immCB[8]  = instruction[13];
    assign immCB[9]  = instruction[14];
    assign immCB[10] = instruction[15];
    assign immCB[11] = instruction[16];
    assign immCB[12] = instruction[17];
    assign immCB[13] = instruction[18];
    assign immCB[14] = instruction[19];
    assign immCB[15] = instruction[20];
    assign immCB[16] = instruction[21];
    assign immCB[17] = instruction[22];
    assign immCB[18] = instruction[23];

    generate
        for (i = 19; i < 64; i++) begin : CB_SIGN
            assign immCB[i] = instruction[23];
        end
    endgenerate


    logic notSel0, notSel1;

    not #(50) n0(notSel0, ImmSel[0]);
    not #(50) n1(notSel1, ImmSel[1]);

    generate
        for(i = 0; i <64; i++) begin: Mux   
            logic aI, aD, aB, aCB;

            and g0(aI, immI[i], notSel1, notSel0);
            and g1(aD, immD[i], notSel1, ImmSel[0]);
            and g2(aB, immB[i], ImmSel[1], notSel0);
            and g3(aCB, immCB[i], ImmSel[1], ImmSel[0]);
            or g4(imm64[i], aI, aD, aB, aCB);
        end 
    endgenerate


endmodule