`timescale 1ps/1ps

package pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `uvm_analysis_imp_decl(_cpu)
    `uvm_analysis_imp_decl(_iss)

    `include "commit_item.sv"
    `include "commit_monitor.sv"
    `include "commit_agent.sv"
    `include "commit_coverage.sv"
    `include "iss_item.sv"
    `include "iss_monitor.sv"
    `include "commit_scoreboard.sv"
    `include "ooo_env_config.sv"
    `include "ooo_env.sv"
    `include "program_sequence.sv"
    `include "arithmetic_sequence.sv"
    `include "branch_sequence.sv"
    `include "base_test.sv"
    `include "smoke_test.sv"
    `include "soak_test.sv"
    `include "branch_test.sv"
    `include "random_inst_item.sv"
    `include "random_sequence.sv"

endpackage