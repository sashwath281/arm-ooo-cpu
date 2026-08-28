`timescale 1ps/1ps


// Observes the golden reference ISS's commits
// Same two-task pattern as commit_monitor. Broadcasts iss_item via analysis port to the scoreboard.

class iss_monitor extends uvm_monitor;

    `uvm_component_utils(iss_monitor)

    virtual iss_if vif;                 // call the interface
    uvm_analysis_port #(iss_item) ap;   // the analysis port 
    int commit_count;                   // no of commits

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
        commit_count = 0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        if (!uvm_config_db#(virtual iss_if)::get(this, "", "iss_vif", vif))
            `uvm_fatal("NOVIF", "Virtual interface 'iss_vif' not set for iss_monitor")
    endfunction

    task run_phase(uvm_phase phase);
        collect_transactions();
    endtask

    task collect_transactions();
        forever begin
            @(vif.monitor_cb);
            if (vif.monitor_cb.committedValid) begin
                collect_transaction();
            end
        end
    endtask


    task collect_transaction();
        iss_item item;
        item = iss_item::type_id::create("item");
        item.arch_reg = vif.monitor_cb.committedArchReg;
        item.data = vif.monitor_cb.committedData;
        item.pc = vif.monitor_cb.committedPC;
        commit_count++;

        `uvm_info("ISS_MON", $sformatf("Observed: %s", item.convert2string()), UVM_HIGH)
        ap.write(item);
    endtask

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("ISS_MON", $sformatf("Total ISS commits: %0d", commit_count), UVM_LOW)
    endfunction

endclass