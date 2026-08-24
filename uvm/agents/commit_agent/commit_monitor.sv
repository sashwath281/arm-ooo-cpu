`timescale 1ps/1ps


// Observes commit signals and broacasts to next stage
// Ever clock cycle, it samples signals via the monitor clocking block 
// If committedValid fires, it packages a commit_item
// Broadcasts it via the analysis port for all downstream subscribers


class commit_monitor extends uvm_monitor; 

    // Register with UVM Factory
    `uvm_component_utils(commit_monitor)


    // Virtual interface handle
    virtual commit_if vif; 

    // Analysis port for broadcasting commit items to subscribers (scoreboard, coverage)
    uvm_analysis_port #(commit_item) ap;

    // Cycle counter for logging/debugging
    int cycle_count; 

    // Constructor 
    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);           // creates a new analysis port
        cycle_count = 0; 
    endfunction


    // The agent can externally force a reset on all children. Thats why this is a virtual function.
    virtual function void handle_reset();
        cycle_count = 0;            // Reset the cycle count
        `uvm_info("MON", "Reset", UVM_MEDIUM)   // A medium level message to indicate Reset
    endfunction


    // Build phase - this fetches the virtual interface
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual commit_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "Virtual interface is not set for commit_monitor")
    
    endfunction


    // Run phase - the main monitoring loop
    task run_phase(uvm_phase phase);
        collect_transactions();
    endtask


    // Outer loop - happens one interation every cycle
    task collect_transactions();
        forever begin                   // runs for entire sim
            @(vif.monitor_cb);          // wait for a clock edge. next time clocking block's sampling event occurs. 
            
            // On reset assertion, wait for it to deassert before continuing
            // we directly check reset and not through the cb to check for immediate/async resets. 
            if (vif.reset) begin
                `uvm_info("MON", "Reset detected", UVM_MEDIUM)
                @(negedge vif.reset);
                `uvm_info("MON", "Reset released", UVM_MEDIUM)
            end

            cycle_count++;              // increment cycle count

            if (vif.monitor_cb.committedValid) begin
                collect_transaction();
            end 
        end 
    endtask
                

    // Inner loop - build and send one commit_item only
    task collect_transaction();
        commit_item item; 
        item = commit_item::type_id::create("item");            // Factory creates a fresh commit_item object.

        item.arch_reg = vif.monitor_cb.committedArchReg;        // the monitor collects the sampled data from the interface and connects it to the commit_item object. 
        item.data = vif.monitor_cb.committedData;
        item.pc = vif.monitor_cb.committedPC;
        item.cycle = cycle_count;

        `uvm_info("MONITOR", $sformatf("Observed: %s", item.convert2string()), UVM_MEDIUM)
        ap.write(item);   // the object gets handed off to the analysis port form where it it broadcasted to whatever is connected. 
    
    endtask

endclass