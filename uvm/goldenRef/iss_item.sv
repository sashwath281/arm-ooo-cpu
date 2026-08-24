`timescale 1ps/1ps


// Transaction class for ISS (golden reference) commits
// Mirrors commit_item's fields. Kept separate since it represents "expected" data, distinct from "observed" data.

class iss_item extends uvm_sequence_item;

    `uvm_object_utils(iss_item)

    bit [4:0] arch_reg;
    bit [63:0] data;
    bit [63:0] pc;

    function new(string name = "iss_item");
        super.new(name);
    endfunction

    virtual function string convert2string();
        return $sformatf("PC=0x%h X%0d <= 0x%h", 
                          pc, arch_reg, data);
    endfunction

endclass