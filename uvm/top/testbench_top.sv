`timescale 1ps/1ps

// Wires interface signals to DUT ports so the monitor can observe commits later.
// generates clock/reset and runs the CPU autonomously.

import uvm_pkg::*;
`include "uvm_macros.svh"
import pkg::*;


module tb_top;

    // Clock and reset
    logic clk;
    logic reset;


    // Golden reference ISS signals
    logic iss_step;
    logic iss_committedValid;
    logic [4:0] iss_committedArchReg;
    logic [63:0] iss_committedData;
    logic [63:0] iss_committedPC;
    logic iss_done;

    assign iss_step = 1'b1;          // step every cycle for now (simple)
   
    // Clock generation (500 MHz — 2000 ps period)
    initial clk = 0;
    always #1000 clk = ~clk;  // toggle every 100ps


    // hold reset high for a few cycles then release
    initial begin
        reset = 1;
        repeat (5) @(posedge clk);
        reset = 0;
    end

    // Interface instance
    commit_if cif (.clk(clk), .reset(reset));       // interface to DUT
    iss_if issvif (.clk(clk), .reset(reset));

    // Memory backend signals
    logic memReq;
    logic [63:0] memAddr;
    logic memRespValid;
    logic [255:0] memRespData;


    // DUT instance
    // Wire the interface signals to the CPU's ports
    OoOCPU dut(.clk(clk), .reset(reset));

    // Our OOO CPU only has clk and reset as inputs. so for the interface to access the respective signals, we directly wire them through the DUT's internal signals. 
    assign cif.committedValid = dut.commit.rob_commit_valid;
    assign cif.committedArchReg = dut.commit.rob_commit_arch_dest;
    assign cif.committedPC = dut.commit.rob_commit_pc;
    assign cif.committedData = 64'h0;        // placeholder for now

    assign cif.pcOut = dut.pc;
    assign cif.stallOut = 1'b0;
    assign cif.robEmpty = 1'b0;
    assign cif.robFull = 1'b0;

    legv8 #(.PROGRAM_FILE("sw/tests/test01_AddiB.arm")) iss(
        .clk(clock),
        .reset(reset),
        .step(1'b1),
        .committedValid(issvif.committedValid),
        .committedArchReg(issvif.committedArchReg),
        .committedData(issvif.committedData),
        .committedPC(issvif.committedPC),
        .done(issvif.done));


    // Register interface handle in config_db so the monitor can retrieve it
    initial begin
        uvm_config_db#(virtual commit_if)::set(null, "*", "vif", cif);
        uvm_config_db#(virtual iss_if)::set(null, "*", "iss_vif", issvif);
    end


    // Launch UVM test
    initial begin
        run_test("base_test");
    end

endmodule