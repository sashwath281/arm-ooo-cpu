`timescale 1ps/1ps


// branch_sequence — Runs the branch-heavy test program

class branch_sequence extends program_sequence;

    `uvm_object_utils(branch_sequence)

    function new(string name = "branch_sequence");
        super.new(name);
        program_file = "sw/tests/test02_CBZ.arm";  // branch .arm
    endfunction

endclass 