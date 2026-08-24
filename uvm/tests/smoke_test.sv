`timescale 1ps/1ps


// module for a quick sanity check. Shortest test. Runs the CPU for 100 μs.
// Used at the start of every regression to catch obvious compile/setup failures fast before running longer tests.

class smoke_test extends base_test;

    `uvm_component_utils(smoke_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Override configure, smoke test = fast, no coverage
    virtual function void configure(ooo_env_config env_config);
        super.configure(env_config);
        env_config.coverage_enable = 0;    // smoke tests skip coverage for speed
    endfunction


    // Override run_phase, shorter duration than base_test
    task run_phase(uvm_phase phase);

        arithmetic_sequence seq; 

        phase.raise_objection(this);
        `uvm_info("SMOKE", "smoke_test starting", UVM_LOW)

        // Create and start the sequence on the agent's sequencer
        seq = arithmetic_sequence::type_id::create("seq");
        seq.start(env.commit_ag.seqr);

        #100000;   // The cpu runs for 100 us

        `uvm_info("SMOKE", "smoke_test ending", UVM_LOW)
        
        phase.drop_objection(this);
    endtask

endclass