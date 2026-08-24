`timescale 1ps/1ps


// Observation interface for the golden reference ISS
// Same pattern as commit_if, but bundles the ISS's own commit signals instead of the DUT's.

interface iss_if (input logic clk, input logic reset);

    logic committedValid;
    logic [4:0] committedArchReg;
    logic [63:0] committedData;
    logic [63:0] committedPC;
    logic done;


    clocking monitor_cb @(posedge clk);
        default input #1step;
        input committedValid, committedArchReg, committedData, committedPC, done;
    
    endclocking

    modport monitor_mp (
        clocking monitor_cb,
        input reset
    );

endinterface