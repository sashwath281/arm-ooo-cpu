`timescale 1ps/1ps


class branch_test extends base_test;

    `uvm_component_utils(branch_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        branch_sequence seq;
        
        phase.raise_objection(this);
        `uvm_info("BRANCH_TEST", "branch_test starting", UVM_LOW)

        seq = branch_sequence::type_id::create("seq");
        seq.start(env.commit_ag.seqr);

        #500000;

        `uvm_info("BRANCH_TEST", "branch_test ending", UVM_LOW)
        phase.drop_objection(this);
        
    endtask

endclass