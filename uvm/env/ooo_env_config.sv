`timescale 1ps/1ps


// Environment configuration object whioch holds all knobs for configuring the environment.
// Test creates one, sets fields, puts into config_db.
// Env reads it in build_phase and configures children.

class ooo_env_config extends uvm_object;

    `uvm_object_utils(ooo_env_config)       // Register with UVM Factory


    bit coverage_enable;        // should we create the coverage collector?
    bit reporting_verbose;      // is there extra uvm_info at INFO level?
    int max_commits;            // stop after this many commits (0 means no limit)
    int timeout_ns;             // hard timeout

    // Constructor with defaults
    function new(string name = "ooo_env_config");
        super.new(name);
        coverage_enable = 1;      // on by default
        reporting_verbose = 0;
        max_commits = 0;          // 0 means no limit
        timeout_ns = 1000;        // 1 us default
    
    endfunction


    // print for debug
    virtual function string convert2string();
        return $sformatf("coverage=%0d verbose=%0d max_commits=%0d timeout=%0dns",
                          coverage_enable, reporting_verbose, max_commits, timeout_ns);
    endfunction

endclass