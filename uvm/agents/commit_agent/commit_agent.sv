`timescale 1ps/1ps


// Passive agent wrapping the commit monitor
// For a self-contained CPU we only observe (no driving).
// So this agent is only a monitor, no driver, no sequencer.

class commit_agent extends uvm_agent;

    `uvm_component_utils(commit_agent)

    // child component - monitor, created in build_phase
    commit_monitor mon;

    // agents own analysis port
    uvm_analysis_port #(commit_item) ap;

    // bare Sequencer, currently unused but there for structure. 
    uvm_sequencer #(commit_item) seqr;

    // Virtual interface for watching reset at the agent level
    virtual commit_if vif;


    // Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction


    // Build phase — create the monitor and the sequencer
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = commit_monitor::type_id::create("mon", this);
        seqr = uvm_sequencer#(commit_item)::type_id::create("seqr", this);
        
        // Check for virtual interface in config_db
        if (!uvm_config_db#(virtual commit_if)::get(this, "", "vif", vif))   
            `uvm_fatal("NOVIF", "Virtual interface not set for commit_agent")
    endfunction


    // wire monitor's port to agent's port
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        mon.ap.connect(ap);         // This is a PROXY. this is to ensure we always talk via the agent and not worry about the internal connections. 
    endfunction


    // Reset watcher and dispatches to all reset_handler children
    task run_phase(uvm_phase phase);
        forever begin
            @(posedge vif.reset);
            `uvm_info("AGENT", "Reset detected", UVM_MEDIUM)
            handle_reset_all_children();
        end
    endtask


    // Iterate children, call handle_reset on any that implement it
    function void handle_reset_all_children();
        uvm_component children[$];  // queue of child components. Use a queue as we dont have a fixed num of components. 
        commit_monitor mon_h;
        
        get_children(children);     // every uvm_component has this method. Fills the queue children 
                                    // with handles to every child of calling component
        
        foreach (children[i]) begin
            if ($cast(mon_h, children[i])) begin
                mon_h.handle_reset();
            end
        
        //  if($cast(seqr_h, children[i])) begin
        //      seqr_h.handle_reset();
        //  end

        
        end
    endfunction

endclass