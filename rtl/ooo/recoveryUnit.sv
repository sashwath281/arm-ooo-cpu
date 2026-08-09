`timescale 1ps/1ps

module recoveryUnit (
    input logic clk,
    input logic reset,

    // From execute stage (branch resolution)
    input logic branchResolved,
    input logic branch_actualTaken,
    input logic [63:0] branch_actualTarget,
    input logic branch_predictedTaken,
    input logic [63:0] branch_predictedTarget,
    input logic [4:0] branch_checkpoint_id,
    input logic [63:0] branch_pc,

    // Misprediction outputs
    output logic mispredict,
    output logic [63:0] redirect_pc,
    output logic [4:0] restore_checkpoint_id,

    // Flush signal to all modules
    output logic flush,

    // To RAT (trigger checkpoint restore)
    output logic rat_restore_valid,
    output logic [4:0] rat_restore_id,

    // To gshare (update predictor)
    output logic bp_update_valid,
    output logic [63:0] bp_update_pc,
    output logic bp_update_taken);


    // Misprediction detection
    logic direction_wrong;
    logic target_wrong;


    assign direction_wrong = branch_actualTaken != branch_predictedTaken;
    assign target_wrong = branch_actualTaken && branch_predictedTaken && (branch_actualTarget != branch_predictedTarget);
    assign mispredict = branchResolved && (direction_wrong || target_wrong);


    // Redirect PC
    // If branch was actually taken - go to actual target
    // If branch was actually not-taken - go to branch PC + 4
    assign redirect_pc = branch_actualTaken ? branch_actualTarget : (branch_pc + 64'd4);


    // Flush and restore
    assign flush = mispredict;
    assign restore_checkpoint_id = branch_checkpoint_id;
    assign rat_restore_valid = mispredict;
    assign rat_restore_id = branch_checkpoint_id;


    // Predictor update (always, not just on mispredict)
    assign bp_update_valid = branchResolved;
    assign bp_update_pc = branch_pc;
    assign bp_update_taken = branch_actualTaken;


endmodule