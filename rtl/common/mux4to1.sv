`timescale 1ps/1ps

module mux4to1 (out, a, b, c, d, sel);

    output logic out;
    input  logic a, b, c, d;
    input  logic [1:0] sel;

    logic lowMux;
    logic highMux;

    mux2to1 m1 (
        .out(lowMux),
        .in0(a),
        .in1(b),
        .sel(sel[0])
    );

    mux2to1 m2 (
        .out(highMux),
        .in0(c),
        .in1(d),
        .sel(sel[0])
    );

    mux2to1 m3 (
        .out(out),
        .in0(lowMux),
        .in1(highMux),
        .sel(sel[1])
    );

endmodule