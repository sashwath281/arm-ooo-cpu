`timescale 1ps/1ps


// Transaction class for a committed instruction observed by the monitor. 
// Extends uvm_sequence_item - the data of that flows in between. 
// components used include - monitor to scoreboard and monitor to coverage.
// An object

class commit_item extends uvm_sequence_item;

    // Register with UVM factory so we can create objects of this type dynamically
    `uvm_object_utils(commit_item)


    // Fields observed at commit
    bit [4:0] arch_reg;         // which arch register was written
    bit[63:0] data;             // what value was written
    bit[63:0] pc;               // PC of committed instruction
    int cycle;                  // cycle at which the instruction committed (monitors own field)


    // Constructor 
    function new(string name = "commit_item");
        super.new(name);
    endfunction


    // Debug helper (not used for now)
    virtual function string convert2string();
        return $sformatf("commit_item: arch_reg=%0d data=0x%h pc=0x%h cycle=%0d",
                                       arch_reg, data, pc, cycle);
    
    endfunction

endclass