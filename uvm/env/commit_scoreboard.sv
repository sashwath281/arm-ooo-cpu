`timescale 1ps/1ps


// Compares real CPU commits vs ISS commits
// Receives commit_item from the real CPU's monitor and iss_item from the ISS's monitor, via TWO separate analysis ports.
// Both streams commit in-order, so we queue each side and compare in FIFO order — commit N from CPU should match commit N from ISS.

class commit_scoreboard extends uvm_component;

    `uvm_component_utils(commit_scoreboard)

    // Two analysis imports (one per input stream)
    uvm_analysis_imp_cpu#(commit_item, commit_scoreboard) cpu_export;
    uvm_analysis_imp_iss#(iss_item, commit_scoreboard) iss_export;

    // Queues holding items not yet matched
    commit_item cpu_queue[$];
    iss_item iss_queue[$];

    // Statistics
    int match_count;
    int mismatch_count;
    int total_compared;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cpu_export = new("cpu_export", this);
        iss_export = new("iss_export", this);
        
        match_count = 0;
        mismatch_count = 0;
        total_compared = 0;
    endfunction 

    // Called automatically when CPU monitor broadcasts
    virtual function void write_cpu(commit_item t);
        cpu_queue.push_back(t);
        compare();
    endfunction

    // Called automatically when ISS monitor broadcasts
    virtual function void write_iss(iss_item t);
        iss_queue.push_back(t);
        compare();
    endfunction

    // Compare front of both queues whenever both have data
    function void compare();
        commit_item cpu_t;
        iss_item iss_t;
        bit match;

        while (cpu_queue.size() > 0 && iss_queue.size() > 0) begin
            cpu_t = cpu_queue.pop_front();
            iss_t = iss_queue.pop_front();
            total_compared++;

            match = (cpu_t.pc == iss_t.pc) && (cpu_t.arch_reg == iss_t.arch_reg) && (cpu_t.data == iss_t.data);

            if (match) begin
                match_count++;
                `uvm_info("SB", $sformatf("MATCH  #%0d: %s", total_compared, cpu_t.convert2string()), UVM_HIGH)
            end

            else begin
                mismatch_count++;
                `uvm_error("SB", $sformatf(
                    "MISMATCH #%0d:\n  CPU: %s\n  ISS: %s",
                    total_compared, cpu_t.convert2string(), iss_t.convert2string()))
            end
        end

    endfunction

    // Report phase (the final summary)
    function void report_phase(uvm_phase phase);
        
        super.report_phase(phase);
        `uvm_info("SB", "Scoreboard", UVM_LOW)
        `uvm_info("SB", $sformatf("Total compared: %0d", total_compared), UVM_LOW)
        `uvm_info("SB", $sformatf("Matches: %0d", match_count), UVM_LOW)
        `uvm_info("SB", $sformatf("Mismatches: %0d", mismatch_count), UVM_LOW)
        
        if (cpu_queue.size() > 0)
            `uvm_warning("SB", $sformatf("CPU queue has %0d unmatched items left over", cpu_queue.size()))
        if (iss_queue.size() > 0)
            `uvm_warning("SB", $sformatf("ISS queue has %0d unmatched items left over", iss_queue.size()))

    endfunction

endclass