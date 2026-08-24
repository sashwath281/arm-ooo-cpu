`timescale 1ps/1ps


// Functional coverage collector - Subscribes to the commit agent's analysis port.
// Each committed instruction arrives in write() and samples covergroups tracking arch_reg, PC region, and commit gaps.
// At end of simulation, report_phase prints coverage percentage.

class commit_coverage extends uvm_subscriber #(commit_item);

    `uvm_component_utils(commit_coverage)       // Register with UVM factory

    int last_commit_cycle;                      // a running memory of what cycle the prev commit happened. 
    int commit_gap_value;                       // HOW MANY CYCLES BETWEEN PREV COMMIT AND THIS ONE. 

    
    commit_item current_item;                   // The item being sampled. the covergroups reference this


    // Covergroups

    // Which architectural register was written
    // 100% coverage is seen when all bins are touched atleast once. 
    covergroup cg_arch_reg;
        option.per_instance = 1;        // own independent checklist
        cp_arch_reg: coverpoint current_item.arch_reg {
            bins reg_[] = {[0:30]};     // one bin per register X0-X30
        }
    endgroup


    // PC range - Here the pc gets divided into 4 buckets to accomodate all values. 
    // 100% coverage is acheived when we have seen commits from all bins. 
    covergroup cg_pc_range;
        option.per_instance = 1;
        cp_pc_range: coverpoint current_item.pc {
            bins low = {[64'h0000_0000_0000_0000 : 64'h0000_0000_0000_00FF]};
            bins mid_low = {[64'h0000_0000_0000_0100 : 64'h0000_0000_0000_0FFF]};
            bins mid_high = {[64'h0000_0000_0000_1000 : 64'h0000_0000_0000_FFFF]};
            bins high = {[64'h0000_0000_0001_0000 : 64'hFFFF_FFFF_FFFF_FFFF]};
        }
    endgroup


    // Test both dense and sparse commit patterns 
    // A good ooo should have a mix of all bins. 
    covergroup cg_commit_gap;
        option.per_instance = 1;
        cp_gap: coverpoint commit_gap_value {       // value we calculate through .write()
            bins back_2_back = {0};
            bins short_gap = {[1:5]};
            bins med_gap = {[6:20]};
            bins long_gap = {[21:$]};
        }
    endgroup


    // did every register get written from every part of the program. 
    covergroup cg_reg_x_pc;
        option.per_instance = 1;
        cp_reg: coverpoint current_item.arch_reg {
            bins reg_[] = {[0:30]};
        }
        
        cp_pc: coverpoint current_item.pc {
            bins low = {[64'h0000_0000_0000_0000 : 64'h0000_0000_0000_0FFF]};
            bins high = {[64'h0000_0000_0000_1000 : 64'hFFFF_FFFF_FFFF_FFFF]};
        }
        
        cross_reg_pc: cross cp_reg, cp_pc;      // automatically creates bins for every conbination
    endgroup                                    // 31 reg x 2 PC =  62 total cross bins



    // Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);        // the analysis_export port gets created automatically by uvm_subscriber
        cg_arch_reg = new();
        cg_pc_range = new();
        cg_commit_gap = new();
        cg_reg_x_pc = new();
        last_commit_cycle = 0;
        commit_gap_value = 0;
    endfunction


    // Write method — called every time monitor broadcasts
    virtual function void write(commit_item t);
        current_item = t;
        
        // Compute gap since last commit
        commit_gap_value = t.cycle - last_commit_cycle;
        last_commit_cycle = t.cycle;

        // We need to .sample() gteh covergroups as this is what triggers covergroups
        // to record Data in the bins. Without this the covergroups just exist, don't record anything. 
        cg_arch_reg.sample();
        cg_pc_range.sample();
        cg_commit_gap.sample();
        cg_reg_x_pc.sample();

        // Return the particular item as a string. HIGH value so will mostly get print. 
        `uvm_info("COV", $sformatf("Sampled: %s", t.convert2string()), UVM_HIGH)
    
    endfunction


    // Reset handler
    virtual function void handle_reset();
        last_commit_cycle = 0;
        commit_gap_value = 0;
        `uvm_info("COV", "Reset asserted", UVM_MEDIUM)
    endfunction


    // print coverage at end of simulation
    // get_coverage() is a built in method every covergroup has. Returns a float (0-100) representing percentage of bins hit.
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COV", "Coverage Report", UVM_LOW)
        `uvm_info("COV", $sformatf("Arch Register: %0.2f%%", cg_arch_reg.get_coverage()),   UVM_LOW)
        `uvm_info("COV", $sformatf("PC Range: %0.2f%%", cg_pc_range.get_coverage()),   UVM_LOW)
        `uvm_info("COV", $sformatf("Commit Gap: %0.2f%%", cg_commit_gap.get_coverage()), UVM_LOW)
        `uvm_info("COV", $sformatf("Reg x PC Cross: %0.2f%%", cg_reg_x_pc.get_coverage()),   UVM_LOW)
    endfunction

endclass