`timescale 1ps/1ps


// arithmetic_sequence — Runs the arithmetic heavy test program

class arithmetic_sequence extends program_sequence;

    `uvm_object_utils(arithmetic_sequence)

    function new(string name = "arithmetic_sequence");
        super.new(name);
        program_file = "sw/tests/test01_AddiB.arm";  // arithmetic .arm
    endfunction

endclass