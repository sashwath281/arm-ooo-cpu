`timescale 1ps/1ps


// Long-running stress test which runs the CPU for 5 ms — 10x longer than base_test.
// Used for deeper coverage runs and to catch bugs that only appear after long execution 
// examples include state accumulation, ROB wrap, register pressure over time.

class soak_test extends base_test;

    `uvm_component_utils(soak_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Override configure, soak test = full coverage + verbose
    virtual function void configure(ooo_env_config env_config);
        super.configure(env_config);
        env_config.coverage_enable = 1;
        env_config.reporting_verbose = 1;
        env_config.timeout_ns = 10000;      // longer timeout
    endfunction

    // Override run_phase for a much longer duration
    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("SOAK", "soak_test starting (5 ms)", UVM_LOW)

        #5000000;   // 5 ms = 5000 us

        `uvm_info("SOAK", "soak_test ending", UVM_LOW)
        phase.drop_objection(this);
    
    endtask

endclass