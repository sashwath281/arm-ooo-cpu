`timescale 1ps/1ps


// Top-level environment
// Contains all agents and downstream analysis components.

class ooo_env extends uvm_env;

    `uvm_component_utils(ooo_env)

    // Sub-components
    commit_agent commit_ag;
    commit_coverage cov; 
    commit_scoreboard sb;
    iss_monitor iss_mon;
    

    // config object handle 
    ooo_env_config cfg; 

    // Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction


    // Build phase — creating agents
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Retrieve config object via config_db
        if (!uvm_config_db#(ooo_env_config)::get(this, "", "cfg", cfg)) begin
            `uvm_warning("ENV", "No ooo_env_config found — using defaults")     // we use uvm_warning and not uvm_fatal because our oo_env_config has defaults which can still run
            cfg = ooo_env_config::type_id::create("cfg");
        end

        `uvm_info("ENV", $sformatf("Config: %s", cfg.convert2string()), UVM_LOW)

        // create a agent with this as the parent.
        commit_ag = commit_agent::type_id::create("commit_ag", this);
    
        // Conditionally create the coverage collector
        if (cfg.coverage_enable) begin
            // creating the coverage collector with this as the parent
            cov = commit_coverage::type_id::create("cov", this);
            `uvm_info("ENV", "Coverage collector created", UVM_LOW)
        end

        else begin
            `uvm_info("ENV", "Coverage disabled so no collector created", UVM_LOW)
        end

        // create the scoreboard and instruction view monitor
        sb = commit_scoreboard::type_id::create("sb", this);
        iss_mon = iss_monitor::type_id::create("iss_mon", this);

    endfunction


    // wire agents to scoreboard/coverage
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        if (cfg.coverage_enable) begin
            commit_ag.ap.connect(cov.analysis_export);
        end
        
        commit_ag.ap.connect(sb.cpu_export);
        iss_mon.ap.connect(sb.iss_export);

    endfunction

endclass