`timescale 1ps/1ps


// Base sequence for program-level tests
// The CPU is self-contained meaning it runs its own instruction memory.
// So sequences here select which .arm program to load, and not per-cycle stimulus.
// Subclasses override program_file with the specific test.

class program_sequence extends uvm_sequence #(commit_item);

    `uvm_object_utils(program_sequence)

    // Program file this sequence targets
    string program_file;

    function new(string name = "program_sequence");
        super.new(name);
        program_file = "sw/tests/test01_AddiB.arm";  // default for now
    endfunction

    // log the program being run
    // Since the CPU is autonomous, the sequence here is really just a scope for reporting and grouping
    virtual task body();
        `uvm_info("SEQ", $sformatf("Running program: %s", program_file), UVM_LOW)
        
        // In a driven agent, we'd generate items here.
        // For our passive agent, we just wait — the CPU runs autonomously.
        // The test's run_phase handles simulation duration via objections.
        #1;   // yield once so the sequence "runs"
    endtask

endclass