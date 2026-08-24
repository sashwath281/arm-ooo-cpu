`timescale 1ps/1ps

// Base UVM test
// Top-level runnable class. Instantiates the env.
// Uses raise_objection/drop_objection to control run_phase length.

class base_test extends uvm_test;

    `uvm_component_utils(base_test)     // Register with UVM Factory

    // Environment instance
    ooo_env env;
    ooo_env_config env_cfg;

    // Track commit count across the simulation
    int totalCommits; 

    // Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);
        totalCommits = 0;
    endfunction


    // Build phase — create the environment
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Create config object with default values
        env_cfg = ooo_env_config::type_id::create("env_cfg");
        configure(env_cfg);      // Subclasses can override values before setting into config_db

        // Put into config_db so environment can retrieve it
        uvm_config_db#(ooo_env_config)::set(this, "env", "cfg", env_cfg);

        // create the environment
        env = ooo_env::type_id::create("env", this);
    
    endfunction

    // Virtual method — subclasses override to change config
    virtual function void configure(ooo_env_config env_config);
        // Base defaults — subclasses can override
        env_config.coverage_enable = 1;
        env_config.reporting_verbose = 0;
        env_config.max_commits = 0;
        env_config.timeout_ns = 1000;
        
    endfunction


    // print the full hierarchy
    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        `uvm_info("TEST", "UVM Component Hierarchy", UVM_LOW)
        uvm_top.print_topology();       // both are built-in uvm handle and method

    endfunction


    // hold simulation open for a fixed time
    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("TEST", "base_test starting", UVM_LOW)

        // Let the CPU run for 500 ns
        #500000;

        `uvm_info("TEST", "base_test ending", UVM_LOW)
        
        phase.drop_objection(this);
    endtask

    // summary at end of simulation
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("TEST", "Test Summary", UVM_LOW)
        `uvm_info("TEST", $sformatf("Test class: %s", this.get_type_name()), UVM_LOW)
        `uvm_info("TEST", $sformatf("Simulation time: %0t", $time), UVM_LOW)

    endfunction

endclass