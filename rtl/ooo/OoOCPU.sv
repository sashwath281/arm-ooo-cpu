`timescale 1ps/1ps

module OoOCPU (clk, reset);
    input logic clk, reset;

//  PHASE 1 — FETCH (unchanged from PipelinedCPU)

    logic [63:0] pc, pcplus4, next_pc;
    logic pcAdder_cout;
    logic [63:0] pcAdder_carry;
    logic PCWrite, IFID_Write, IFID_Flush;
    logic [31:0] IFID_instruction_in;
    

    PC programCounter (.clk(clk), .reset(reset), .writeEnable(PCWrite),
                       .next_pc(next_pc), .pc(pc));

    // Computes PC+4 (the default next PC)
    adder64 pcAdder (.sum(pcplus4), .cout(pcAdder_cout), .carry(pcAdder_carry),     // pcAdder_cout and pcAdder_carry are unused
                     .a(pc), .b(64'd4), .cin(1'b0));
    

    // I-Cache signals
    logic [31:0] instruction;               // Instruction from cache.
    logic icache_ready;                     // The stall or go signal from I-Cache
    
    logic icache_mem_req;                   // Request to memory backend (Hey, I need a signal)
    logic [63:0] icache_mem_addr;           // Block-aligned request address
    logic icache_mem_resp_valid;            // Response from memory backend (Valid)
    logic [255:0] icache_mem_resp_data;     // Incoming 256-bit block

    icache instructionCache (.clk(clk), .reset(reset), .pc(pc), .valid(1'b1),       // Valid is always 1 as the cache always servives requests in our CPU
                             .instruction(instruction), .ready(icache_ready),
                             .mem_req(icache_mem_req), .mem_addr(icache_mem_addr),
                             .mem_resp_valid(icache_mem_resp_valid),
                             .mem_resp_data(icache_mem_resp_data));

    // The fake DRAM backend for the I-Cache
    // I-Cache misses, asserts mem_req, mem_backend counts 10 cycles, responds, I-Cache fills and process repeats
    mem_backend imemBackend (.clk(clk), .reset(reset),.req_valid(icache_mem_req),
                              .req_addr(icache_mem_addr),.resp_valid(icache_mem_resp_valid),
                              .resp_data(icache_mem_resp_data));


    // Branch Predictor

    logic predict_taken_if;                 // if - IF stage prediction of taken/not-taken
    logic take_prediction_if;
    logic btb_hit;                          // 
    logic [63:0] predict_target_if;
    logic [7:0] predict_bhr_snapshot;       // goes into IF/ID pipeline register
    logic [63:0] predicted_next_pc;

    // Fires only on branch resolution, coming from the recovery unit at EX stage
    logic gshare_update_valid;
    logic [63:0] gshare_update_pc;
    logic [7:0] gshare_update_bhr;
    logic gshare_update_taken;

    logic btb_update_valid;
    logic [63:0] btb_update_pc;
    logic [63:0] btb_update_target;

    gshare branchPredictor (.clk(clk), .reset(reset), .predict_pc(pc), .predict_taken(predict_taken_if),
                            .predict_bhr_snapshot(predict_bhr_snapshot), .update_valid(gshare_update_valid),
                            .update_pc(gshare_update_pc), .update_bhr(gshare_update_bhr), .update_taken(gshare_update_taken));

    btb branchTargetBuffer (.clk(clk), .reset(reset), .predict_pc(pc),.btb_hit(btb_hit), .predict_target(predict_target_if),
                            .update_valid(btb_update_valid), .update_pc(btb_update_pc), .update_target(btb_update_target));


    // btb_hit - yes, I know where the branch goes
    // predict_taken_if - yes, gshare thinks the branch will be taken
    assign take_prediction_if = btb_hit & predict_taken_if;     // do we take the prediction this cycle?


    // First PC mux: Picks between PC+4 and the BTB target
    // sel = 0: out = a = pcplus4 (no prediction)
    // sel = 1: out = b = predict_target_if (take prediction)
    mux64_2to1 predicted_pc_mux (.a(pcplus4), .b(predict_target_if), .sel(take_prediction_if), .out(predicted_next_pc));


    // Fetch can advance if rename can accept the current instruction, dispatch can accept the current instruction, 
    // and the I-cache has the instruction ready. 
    // Else everything freezes in fetch
    assign PCWrite   = !rename_stall && !dispatch_stall && icache_ready;
    assign IFID_Write = !rename_stall && !dispatch_stall && icache_ready;


    // Flush everything in IF/ID if there is a branch misprediction in EX (everything fetched is wrong)
    // or decode found and uncoditional branch (everything in fetch is on the wrong path)
    assign IFID_Flush = recovery_flush_reg || uncond_branch_in_decode;


    logic [63:0] branch_or_predict_pc;      // PC of the branch or prediction

    // Second PC mux: override with unconditional branch target
    // sel = 0: out = a = predicted_next_pc (either PC+4 or BTB target)
    // sel = 1: out = b = uncond_branch_target (unconditional branch in decode stage)
    mux64_2to1 uncond_pc_mux (.a(predicted_next_pc), .b(uncond_branch_target),
                              .sel(uncond_branch_in_decode), .out(branch_or_predict_pc));


    // Third PC mux: recovery override (misprediction or exception)
    // sel = 0: out = a = branch_or_predict_pc (either predicted or unconditional branch)
    // sel = 1: out = b = recovery_redirect_pc_reg (redirect to correct PC)
    mux64_2to1 final_pc_mux (.a(branch_or_predict_pc), .b(recovery_redirect_pc_reg),
                             .sel(recovery_flush_reg), .out(next_pc));


    // IF/ID Pipeline Registers

    // Mux to pass the correct instruction
    // sel = 0: out = a = instruction (from I-Cache)
    // sel = 1: out = b = 32'b0 (flush the instruction)
    mux32_2to1 ifid_flush_mux (.a(instruction), .b(32'b0), .sel(IFID_Flush), .out(IFID_instruction_in));


    // IF/ID Pipeline Register Outputs
    logic [63:0] IFID_pc, IFID_pcplus4;
    logic [31:0] IFID_instruction;
    logic IFID_predict_taken;
    logic [63:0] IFID_predict_target;
    logic [7:0] IFID_bhr_snapshot;

    register64 IFID_pc_reg (.q(IFID_pc), .d(pc), .writeEnable(IFID_Write), .clk(clk));                                                        // the PC of the instruction (needed by decode to compute branch targets)
    register64 IFID_pcplus4_reg (.q(IFID_pcplus4), .d(pcplus4), .writeEnable(IFID_Write), .clk(clk));                                         // the return address for BL instruction
    register32 IFID_instruction_reg (.q(IFID_instruction), .d(IFID_instruction_in), .writeEnable(IFID_Write), .clk(clk), .reset(reset));      // the 32-bit instruction
    register1 IFID_predict_taken_reg (.q(IFID_predict_taken), .d(take_prediction_if), .writeEnable(IFID_Write), .clk(clk), .reset(reset));    // did we predict this as taken?
    register64 IFID_predict_target_reg (.q(IFID_predict_target), .d(predict_target_if), .writeEnable(IFID_Write), .clk(clk));                 // Where did we predict it would go?
    register8 IFID_bhr_snapshot_reg (.q(IFID_bhr_snapshot), .d(predict_bhr_snapshot), .writeEnable(IFID_Write), .clk(clk), .reset(reset));    // the gshare BHR at prediction time.

    // All six share the writeEnable = IFID_Write - they update tgether or hold together.





//  PHASE 2 — DECODE

    // Control signals from decoder
    logic Reg2Loc, RegWrite, ALUSrc, MemWrite, MemRead, MemToReg, FlagSet, BranchReg, BranchUncond, BranchCond, Link;
    logic [1:0] ALUOp, ImmSel;


    Control control (.instruction(IFID_instruction), .RegWrite(RegWrite), .ALUSrc(ALUSrc),
                     .MemWrite(MemWrite), .MemRead(MemRead), .MemToReg(MemToReg), .BranchUncond(BranchUncond),
                     .BranchCond(BranchCond), .FlagSet(FlagSet), .BranchReg(BranchReg), .Link(Link),
                     .ALUOp(ALUOp), .ImmSel(ImmSel), .Reg2Loc(Reg2Loc));

    logic [63:0] immExt, immShifted;

    // immExt is the sign-extended 64-bit immediate. 
    signextend imm (.instruction(IFID_instruction), .ImmSel(ImmSel), .imm64(immExt));
    shiftLeft SL (.in(immExt), .out(immShifted));


    logic uncond_branch_in_decode;          // redirect pc because decode found unconditional branch?
    logic [63:0] uncond_branch_target;      // target of unconditional branch


    // Unconditional branch detection and target. 
    assign uncond_branch_in_decode = BranchUncond && !recovery_flush_reg && (IFID_instruction != 32'b0) && icache_ready;

    // standard branch target calculation: PC + sign-extended immediate (shifted left by 2)
    assign uncond_branch_target = IFID_pc + immShifted;



    // Decode outputs for rename stage
    logic [4:0] decode_arch_source1;         // source 1 arch reg number
    logic [4:0] decode_arch_source2;         // source 2 arch reg number
    logic [4:0] decode_arch_dest;            // destination arch reg number
    logic decode_has_dest;                   // some instructions don't write (stores, branches)
    logic decode_branch;                  // is this instruction a branch?
    logic decode_load;                    // is this instruction a load?
    logic decode_store;                   // is this instruction a store?
    logic [1:0] decode_alu_op;               // ALU operation for the instruction
    logic [63:0] decode_pc;                  // PC of the instruction being renamed
    logic [63:0] decode_immediate;           // immediate value for the instruction
    logic decode_imm;                        // does this instruction use the immediate value?
    logic decode_uncondBranch;               // is this instruction an unconditional branch?
    logic decode_condBranch;                 // is this instruction a conditional branch?
    logic [63:0] decode_branchTarget;        // target address for the branch instruction
    logic decode_branch_cbz;                 // is this instruction a CBZ instruction?
    logic [10:0] op11;                       // the 11-bit opcode field of the instruction 

    // Assign them with their corresponding values from the IF/ID pipeline register and control signals
    assign decode_arch_source1 = IFID_instruction[9:5];
    assign decode_arch_source2 = Reg2Loc ? IFID_instruction[4:0] : IFID_instruction[20:16];
    assign decode_arch_dest = Link ? 5'd30 : IFID_instruction[4:0];
    assign decode_has_dest  = RegWrite || Link;                         // some instructions dont write (STUR, branches)
    assign decode_branch = BranchCond;
    assign decode_load   = MemRead;
    assign decode_store  = MemWrite;
    assign decode_immediate = immExt;
    assign decode_imm = ALUSrc;
    assign decode_uncondBranch = BranchUncond;
    assign decode_condBranch = BranchCond;
    assign decode_branchTarget = IFID_pc + immShifted;
    assign decode_branch_cbz = (IFID_instruction[31:24] == 8'b10110100);  // CBZ opcode
    assign op11 = IFID_instruction[31:21];

    always_comb begin
        case (op11)
            11'b10001011000: decode_alu_op = 2'b00;  // ADD
            11'b10101011000: decode_alu_op = 2'b00;  // ADDS
            11'b11001011000: decode_alu_op = 2'b01;  // SUB
            11'b11101011000: decode_alu_op = 2'b01;  // SUBS
            11'b10001010000: decode_alu_op = 2'b10;  // AND
            11'b10101010000: decode_alu_op = 2'b11;  // ORR
            default:         decode_alu_op = 2'b00;
        endcase
    end





//  PHASE 3 — RENAME

    // Rename stage
    logic rename_valid;
    logic [5:0] rename_source1, rename_source2;
    logic [5:0] rename_dest, rename_old;
    logic rename_source1_ready, rename_source2_ready;
    logic [63:0] rename_pc;
    logic [1:0] rename_alu_op;
    logic rename_branch, rename_load, rename_store;
    logic [4:0] rename_arch_dest;
    logic rename_stall;
    logic [63:0] rename_immediate;
    logic rename_imm;
    logic rename_uncondBranch, rename_condBranch;
    logic [63:0] rename_branchTarget;
    logic rename_branch_cbz;
    logic dispatch_stall;

    renameStage rename (.clk(clk), .reset(reset),
        // From decode
        .decode_valid(!IFID_Flush && (IFID_instruction != 32'b0) && icache_ready && !uncond_branch_in_decode),
        .decode_arch_source1(decode_arch_source1),
        .decode_arch_source2(decode_arch_source2),
        .decode_arch_dest(decode_arch_dest),
        .decode_has_dest(decode_has_dest),
        .decode_pc(IFID_pc),
        .decode_alu_op(decode_alu_op),
        .decode_branch(decode_branch),
        .decode_load(decode_load),
        .decode_store(decode_store),
        .decode_immediate(decode_immediate),
        .decode_use_imm(decode_imm),
        .decode_uncondBranch(decode_uncondBranch),
        .decode_condBranch(decode_condBranch),
        .decode_branchTarget(decode_branchTarget),
        .decode_branch_cbz(decode_branch_cbz),

        // To dispatch
        .rename_valid(rename_valid),
        .rename_source1(rename_source1),
        .rename_source2(rename_source2),
        .rename_dest(rename_dest),
        .rename_old(rename_old),
        .rename_source1_ready(rename_source1_ready),
        .rename_source2_ready(rename_source2_ready),
        .rename_pc(rename_pc),
        .rename_alu_op(rename_alu_op),
        .rename_branch(rename_branch),
        .rename_load(rename_load),
        .rename_store(rename_store),
        .rename_arch_dest(rename_arch_dest),
        .rename_immediate(rename_immediate),
        .rename_imm(rename_imm),
        .rename_uncondBranch(rename_uncondBranch),
        .rename_condBranch(rename_condBranch),
        .rename_branchTarget(rename_branchTarget),
        .rename_branch_cbz(rename_branch_cbz),

        // Stall
        .stall(rename_stall),

        // From commit (free old phys reg)
        .commit_free_valid(commit_free_valid),
        .commit_free_preg(commit_free_preg),

        // From CDB (clear busy bit)
        .cdb_valid(cdb_valid),
        .cdb_phys_dest(cdb_phys_dest),

        // Checkpoint (on branch dispatch)
        .checkpoint_valid(dispatch_checkpoint_valid),
        .checkpoint_id(dispatch_checkpoint_id),

        // Restore (on misprediction)
        .restore_valid(recovery_flush_reg),
        .restore_id(recovery_restore_id_reg),

        // Flush
        .flush(recovery_flush_reg));



//  PHASE 4 — DISPATCH

    // ROB
    logic rob_dispatch_valid;
    logic [4:0] rob_dispatch_arch_dest;
    logic [5:0] rob_dispatch_dest, rob_dispatch_old;
    logic [63:0] rob_dispatch_pc;
    logic rob_dispatch_branch, rob_dispatch_store;
    logic [4:0] rob_dispatch_idx;
    logic rob_full;
    logic rob_commit_valid;
    logic [4:0] rob_commit_arch_dest;
    logic [5:0] rob_commit_dest, rob_commit_old;
    logic rob_commit_store, rob_commit_branch;
    logic [63:0] rob_commit_pc;
    logic rob_flush_valid;
    logic [63:0] rob_flush_pc;
    logic dispatch_checkpoint_valid;
    logic [4:0] dispatch_checkpoint_id;

    // Issue Queue
    logic iq_full;
    logic issue_valid;
    logic [5:0] issue_dest, issue_source1, issue_source2;
    logic [4:0] issue_rob_idx;
    logic [1:0] issue_alu_op;
    logic issue_load, issue_store;
    logic iq_dispatch_valid;
    logic [5:0] iq_dispatch_dest, iq_dispatch_source1, iq_dispatch_source2;
    logic iq_dispatch_source1_ready, iq_dispatch_source2_ready;
    logic [4:0] iq_dispatch_rob_idx;
    logic [1:0] iq_dispatch_alu_op;
    logic iq_dispatch_load, iq_dispatch_store;
    logic [63:0] iq_dispatch_immediate;
    logic iq_dispatch_imm;
    logic iq_dispatch_uncondBranch;
    logic iq_dispatch_condBranch;
    logic [63:0] iq_dispatch_branchTarget;
    logic iq_dispatch_branch_cbz;
    logic [63:0] issue_immediate;
    logic issue_imm;
    logic issue_uncondBranch;
    logic issue_condBranch;
    logic [63:0] issue_branchTarget;
    logic issue_branch_cbz;

    // Store Queue
    logic [3:0] sq_dispatch_idx;
    logic sq_full;
    logic sq_fwd_hit;
    logic [63:0] sq_fwd_data;
    logic sq_commit_ready;
    logic [63:0] sq_commit_addr, sq_commit_data;
    logic sq_dispatch_valid;
    logic sq_write_valid;
    logic [3:0] sq_write_idx;
    logic [63:0] sq_write_addr, sq_write_data;
    logic sq_fwd_req_valid;
    logic [63:0] sq_fwd_req_addr;
    logic lq_dispatch_valid;
    logic [4:0] sq_rob_idx;

    // Load Queue
    logic [3:0] lq_dispatch_idx;
    logic lq_full;
    logic [5:0] lq_result_dest;
    logic [4:0] lq_result_rob_idx;
    logic lq_exec_valid;
    logic [3:0] lq_exec_idx;
    logic [63:0] lq_exec_addr;
    logic lq_result_valid;
    logic [63:0] lq_result_data;
    logic [3:0] lq_result_idx;
    logic lq_dcache_req;
    logic [63:0] lq_dcache_addr;
    logic lq_dcache_resp_valid;
    logic [63:0] lq_dcache_resp_data;

    dispatchStage dispatch (.clk(clk), .reset(reset),

        // From rename
        .rename_valid(rename_valid),
        .rename_source1(rename_source1),
        .rename_source2(rename_source2),
        .rename_dest(rename_dest),
        .rename_old(rename_old),
        .rename_source1_ready(rename_source1_ready),
        .rename_source2_ready(rename_source2_ready),
        .rename_pc(rename_pc),
        .rename_alu_op(rename_alu_op),
        .rename_branch(rename_branch),
        .rename_load(rename_load),
        .rename_store(rename_store),
        .rename_arch_dest(rename_arch_dest),
        .rename_immediate(rename_immediate),
        .rename_imm(rename_imm),
        .rename_uncondBranch(rename_uncondBranch),
        .rename_condBranch(rename_condBranch),
        .rename_branchTarget(rename_branchTarget),
        .rename_branch_cbz(rename_branch_cbz),

        // Stall
        .stall(dispatch_stall),

        // To ROB
        .rob_dispatch_valid(rob_dispatch_valid),
        .rob_arch_dest(rob_dispatch_arch_dest),
        .rob_dest(rob_dispatch_dest),
        .rob_old(rob_dispatch_old),
        .rob_pc(rob_dispatch_pc),
        .rob_branch(rob_dispatch_branch),
        .rob_store(rob_dispatch_store),
        .rob_idx(rob_dispatch_idx),
        .rob_full(rob_full),

        // To Issue Queue
        .iq_dispatch_valid(iq_dispatch_valid),
        .iq_dest(iq_dispatch_dest),
        .iq_source1(iq_dispatch_source1),
        .iq_source2(iq_dispatch_source2),
        .iq_source1_ready(iq_dispatch_source1_ready),
        .iq_source2_ready(iq_dispatch_source2_ready),
        .iq_rob_idx(iq_dispatch_rob_idx),
        .iq_alu_op(iq_dispatch_alu_op),
        .iq_load(iq_dispatch_load),
        .iq_store(iq_dispatch_store),
        .iq_immediate(iq_dispatch_immediate),
        .iq_imm(iq_dispatch_imm),
        .iq_uncondBranch(iq_dispatch_uncondBranch),
        .iq_condBranch(iq_dispatch_condBranch),
        .iq_branchTarget(iq_dispatch_branchTarget),
        .iq_branch_cbz(iq_dispatch_branch_cbz),
        .iq_full(iq_full),

        // To Store Queue
        .sq_dispatch_valid(sq_dispatch_valid),
        .sq_full(sq_full),

        // To Load Queue
        .lq_dispatch_valid(lq_dispatch_valid),
        .lq_full(lq_full),

        // Checkpoint trigger
        .checkpoint_valid(dispatch_checkpoint_valid),
        .checkpoint_id(dispatch_checkpoint_id));



    rob reorder_buffer (.clk(clk),.reset(reset),

        // Dispatch
        .dispatch_valid(rob_dispatch_valid),
        .dispatch_arch_dest(rob_dispatch_arch_dest),
        .dispatch_dest(rob_dispatch_dest),
        .dispatch_old(rob_dispatch_old),
        .dispatch_pc(rob_dispatch_pc),
        .dispatch_branch(rob_dispatch_branch),
        .dispatch_store(rob_dispatch_store),
        .dispatch_rob_idx(rob_dispatch_idx),
        .full(rob_full),

        // Writeback (from CDB)
        .wb_valid(cdb_valid),
        .wb_rob_idx(cdb_rob_idx),
        .wb_branchTaken(cdb_branchTaken),
        .wb_exception(cdb_exception),

        // Commit
        .commit_valid(rob_commit_valid),
        .commit_arch_dest(rob_commit_arch_dest),
        .commit_dest(rob_commit_dest),
        .commit_old(rob_commit_old),
        .commit_store(rob_commit_store),
        .commit_branch(rob_commit_branch),
        .commit_pc(rob_commit_pc),

        // Flush
        .flush_valid(rob_flush_valid),
        .flush_pc(rob_flush_pc),
        .flush_ack(recovery_flush_reg));


    issueQueue iq (.clk(clk), .reset(reset),

        // Dispatch
        .dispatch_valid(iq_dispatch_valid),
        .dispatch_dest(iq_dispatch_dest),
        .dispatch_source1(iq_dispatch_source1),
        .dispatch_source2(iq_dispatch_source2),
        .dispatch_source1_ready(iq_dispatch_source1_ready),
        .dispatch_source2_ready(iq_dispatch_source2_ready),
        .dispatch_rob_idx(iq_dispatch_rob_idx),
        .dispatch_alu_op(iq_dispatch_alu_op),
        .dispatch_load(iq_dispatch_load),
        .dispatch_store(iq_dispatch_store),
        .dispatch_immediate(iq_dispatch_immediate),
        .dispatch_imm(iq_dispatch_imm),
        .dispatch_uncondBranch(iq_dispatch_uncondBranch),
        .dispatch_condBranch(iq_dispatch_condBranch),
        .dispatch_branchTarget(iq_dispatch_branchTarget),
        .dispatch_branch_cbz(iq_dispatch_branch_cbz),
        .full(iq_full),

        // Wakeup (from CDB)
        .wakeup_valid(cdb_valid),
        .wakeup_phys_reg(cdb_phys_dest),

        // Issue (to execute stage)
        .issue_valid(issue_valid),
        .issue_dest(issue_dest),
        .issue_source1(issue_source1),
        .issue_source2(issue_source2),
        .issue_rob_idx(issue_rob_idx),
        .issue_alu_op(issue_alu_op),
        .issue_load(issue_load),
        .issue_store(issue_store),
        .issue_immediate(issue_immediate),
        .issue_imm(issue_imm),
        .issue_uncondBranch(issue_uncondBranch),
        .issue_condBranch(issue_condBranch),
        .issue_branchTarget(issue_branchTarget),
        .issue_branch_cbz(issue_branch_cbz),

        // Flush
        .flush(recovery_flush_reg));


    storeQueue sq (.clk(clk),.reset(reset),

        // Dispatch
        .dispatch_valid(sq_dispatch_valid),
        .dispatch_sq_idx(sq_dispatch_idx),
        .dispatch_rob_idx(rob_dispatch_idx),
        .full(sq_full),

        // Address + data from execute
        .write_valid(sq_write_valid),
        .write_sq_idx(sq_write_idx),
        .write_addr(sq_write_addr),
        .write_data(sq_write_data),

        // Forwarding (load checks SQ)
        .fwd_req_valid(sq_fwd_req_valid),
        .fwd_req_addr(sq_fwd_req_addr),
        .fwd_hit(sq_fwd_hit),
        .fwd_data(sq_fwd_data),
        .fwd_rob_idx(sq_rob_idx),  


        // Commit
        .commit_valid(commit_sq_valid),
        .commit_ready(sq_commit_ready),
        .commit_addr(sq_commit_addr),
        .commit_data(sq_commit_data),

        // Flush
        .flush(recovery_flush_reg),
        .flush_rob_idx(recovery_restore_id_reg));


    loadQueue lq (.clk(clk), .reset(reset),

        // Dispatch
        .dispatch_valid(lq_dispatch_valid),
        .dispatch_dest(rename_dest),
        .dispatch_rob_idx(rob_dispatch_idx),
        .dispatch_lq_idx(lq_dispatch_idx),
        .full(lq_full),

        // Execute
        .exec_valid(lq_exec_valid),
        .exec_lq_idx(lq_exec_idx),
        .exec_addr(lq_exec_addr),

        // SQ forwarding
        .sq_fwd_hit(sq_fwd_hit),
        .sq_fwd_data(sq_fwd_data),
        .sq_rob_idx(sq_rob_idx),

        // D-Cache
        .dcache_req(lq_dcache_req),
        .dcache_addr(lq_dcache_addr),
        .dcache_resp_valid(lq_dcache_resp_valid),
        .dcache_resp_data(lq_dcache_resp_data),

        // Result to CDB
        .result_valid(lq_result_valid),
        .result_data(lq_result_data),
        .result_phys_dest(lq_result_dest),
        .result_rob_idx(lq_result_rob_idx),
        .result_lq_idx(lq_result_idx),

        // Commit
        .commit_valid(rob_commit_valid && !rob_commit_store && !rob_commit_branch),

        // Flush
        .flush(recovery_flush_reg),
        .flush_rob_idx(recovery_restore_id_reg));




//  PHASE 5 — ISSUE + EXECUTE + WRITEBACK

    // Physical Register File
    logic [5:0] read_phys_reg1, read_phys_reg2;
    logic [63:0] read_data1, read_data2;

    physicalRegFile prf (.clk(clk), .reset(reset),

        // Read
        .read_phys_reg1(read_phys_reg1),
        .read_phys_reg2(read_phys_reg2),
        .read_data1(read_data1),
        .read_data2(read_data2),

        // Write (from CDB)
        .write_valid(cdb_valid),
        .write_phys_reg(cdb_phys_dest),
        .write_data(cdb_result));


    // Execute stage
    logic ex_valid;
    logic [5:0] ex_dest;
    logic [63:0] ex_result;
    logic [4:0] ex_rob_idx;
    logic ex_exception;
    logic ex_sq_write_valid;
    logic [63:0] ex_sq_write_addr, ex_sq_write_data;
    logic ex_lq_exec_valid;
    logic [63:0] ex_lq_exec_addr;
    logic ex_branchResolved;
    logic ex_branch_actualTaken;
    logic [63:0] ex_branch_actualTarget;


    executeStage ex_stage (.clk(clk), .reset(reset),

        // From issue queue
        .issue_valid(issue_valid),
        .issue_dest(issue_dest),
        .issue_source1(issue_source1),
        .issue_source2(issue_source2),
        .issue_rob_idx(issue_rob_idx),
        .issue_alu_op(issue_alu_op),
        .issue_load(issue_load),
        .issue_store(issue_store),
        .issue_immediate(issue_immediate),
        .issue_imm(issue_imm),
        .issue_uncondBranch(issue_uncondBranch),
        .issue_condBranch(issue_condBranch),
        .issue_branchTarget(issue_branchTarget),
        .issue_branch_cbz(issue_branch_cbz),

        // PRF read
        .read_phys_reg1(read_phys_reg1),
        .read_phys_reg2(read_phys_reg2),
        .read_data1(read_data1),
        .read_data2(read_data2),

        // ALU result to CDB
        .ex_valid(ex_valid),
        .ex_dest(ex_dest),
        .ex_result(ex_result),
        .ex_rob_idx(ex_rob_idx),
        .ex_exception(ex_exception),

        // To store queue
        .sq_write_valid(ex_sq_write_valid),
        .sq_write_addr(ex_sq_write_addr),
        .sq_write_data(ex_sq_write_data),

        // To load queue
        .lq_exec_valid(ex_lq_exec_valid),
        .lq_exec_addr(ex_lq_exec_addr),

        // Branch resolution
        .branchResolved(ex_branchResolved),
        .branch_actualTaken(ex_branch_actualTaken),
        .branch_actualTarget(ex_branch_actualTarget),

        // Flush
        .flush(recovery_flush_reg));


    // CDB
    logic cdb_valid;
    logic [5:0] cdb_phys_dest;
    logic [63:0] cdb_result;
    logic [4:0] cdb_rob_idx;
    logic cdb_branchTaken;
    logic cdb_exception;
    logic cdb_from_alu;
    logic cdb_from_lq;

    // Connect execute - SQ
    assign sq_write_valid = ex_sq_write_valid;
    assign sq_write_addr = ex_sq_write_addr;
    assign sq_write_data = ex_sq_write_data;
    assign sq_write_idx = sq_dispatch_idx;
    assign lq_exec_valid = ex_lq_exec_valid;
    assign lq_exec_addr = ex_lq_exec_addr;
    assign lq_exec_idx = lq_dispatch_idx;
    assign sq_fwd_req_valid = ex_lq_exec_valid;
    assign sq_fwd_req_addr = ex_lq_exec_addr;
    assign cdb_from_alu = ex_valid;
    assign cdb_from_lq = lq_result_valid && !ex_valid;  // LQ wins only if ALU idle

    cdb common_data_bus (.clk(clk), .reset(reset),

        // Mux between ALU and LQ results
        .ex_valid(cdb_from_alu || cdb_from_lq),
        .ex_phys_dest(cdb_from_alu ? ex_dest : lq_result_dest),
        .ex_result(cdb_from_alu ? ex_result : lq_result_data),
        .ex_rob_idx(cdb_from_alu ? ex_rob_idx : lq_result_rob_idx),
        .ex_branchTaken(1'b0),
        .ex_exception(cdb_from_alu ? ex_exception : 1'b0),

        // Broadcast
        .cdb_valid(cdb_valid),
        .cdb_phys_dest(cdb_phys_dest),
        .cdb_result(cdb_result),
        .cdb_rob_idx(cdb_rob_idx),
        .cdb_branchTaken(cdb_branchTaken),
        .cdb_exception(cdb_exception));


    // D-Cache connection for loads
    // For now: stub with zero-latency response
    // Replace with real dcache + dmem_backend during cache integration
    assign lq_dcache_resp_valid = lq_dcache_req;
    assign lq_dcache_resp_data  = 64'hDEAD_BEEF;  // placeholder
    


//  PHASE 6 — COMMIT + RECOVERY

    logic commit_free_valid;
    logic [5:0] commit_free_preg;
    logic commit_sq_valid;
    logic commit_flush;
    logic [63:0] commit_flush_pc;
    logic commit_flush_ack;
    
    commitStage commit (.clk(clk), .reset(reset),

        // From ROB
        .rob_commit_valid(rob_commit_valid),
        .rob_commit_arch_dest(rob_commit_arch_dest),
        .rob_commit_dest(rob_commit_dest),
        .rob_commit_old(rob_commit_old),
        .rob_commit_store(rob_commit_store),
        .rob_commit_branch(rob_commit_branch),
        .rob_commit_pc(rob_commit_pc),

        // From ROB (flush)
        .rob_flush_valid(rob_flush_valid),
        .rob_flush_pc(rob_flush_pc),

        // To free list (return old phys reg)
        .free_valid(commit_free_valid),
        .free_preg(commit_free_preg),

        // To store queue (drain store to D-Cache)
        .sq_commit_valid(commit_sq_valid),

        // To fetch (redirect on flush)
        .flush(commit_flush),
        .flush_redirect_pc(commit_flush_pc),
        .flush_ack(commit_flush_ack));


    // Recovery Unit
    logic recovery_mispredict;
    logic recovery_rat_restore_valid;
    logic [4:0] recovery_rat_restore_id;
    logic recovery_bp_update_valid;
    logic [63:0] recovery_bp_update_pc;
    logic recovery_bp_update_taken;
    logic recovery_flush;
    logic [63:0] recovery_redirect_pc;
    logic [4:0] recovery_restore_id;


    logic recovery_flush_reg;
    logic [63:0] recovery_redirect_pc_reg;
    logic [4:0] recovery_restore_id_reg;

    // Register recovery outputs to reduce critical path
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            recovery_flush_reg <= 1'b0;
            recovery_redirect_pc_reg <= 64'd0;
            recovery_restore_id_reg <= 5'd0;
        end else begin
            recovery_flush_reg <= recovery_flush;
            recovery_redirect_pc_reg <= recovery_redirect_pc;
            recovery_restore_id_reg <= recovery_restore_id;
        end
    end


    // Branch prediction info carried through pipeline
    // We need to track predicted direction and target per branch
    // For now we use IFID values latched at dispatch time
    logic ex_branch_predictedTaken;
    logic [63:0] ex_branch_predictedTarget;
    logic [4:0] ex_branch_checkpoint_id;
    logic [63:0] ex_branch_pc;

    // use IFID values directly (works for single-issue)
    assign ex_branch_predictedTaken = IFID_predict_taken;
    assign ex_branch_predictedTarget = IFID_predict_target;
    assign ex_branch_checkpoint_id = rob_dispatch_idx;
    assign ex_branch_pc = IFID_pc;


    recoveryUnit recovery (.clk(clk), .reset(reset),

        // From execute stage
        .branchResolved(ex_branchResolved),
        .branch_actualTaken(ex_branch_actualTaken),
        .branch_actualTarget(ex_branch_actualTarget),
        .branch_predictedTaken(ex_branch_predictedTaken),
        .branch_predictedTarget(ex_branch_predictedTarget),
        .branch_checkpoint_id(ex_branch_checkpoint_id),
        .branch_pc(ex_branch_pc),

        // Misprediction outputs
        .mispredict(recovery_mispredict),
        .redirect_pc(recovery_redirect_pc),
        .restore_checkpoint_id(recovery_restore_id),

        // Flush
        .flush(recovery_flush),

        // To RAT
        .rat_restore_valid(recovery_rat_restore_valid),
        .rat_restore_id(recovery_rat_restore_id),

        // To gshare
        .bp_update_valid(recovery_bp_update_valid),
        .bp_update_pc(recovery_bp_update_pc),
        .bp_update_taken(recovery_bp_update_taken));

    // Wire BP updates from recovery to gshare + BTB
    assign gshare_update_valid = recovery_bp_update_valid;
    assign gshare_update_pc = recovery_bp_update_pc;
    assign gshare_update_bhr = IFID_bhr_snapshot;
    assign gshare_update_taken = recovery_bp_update_taken;

    assign btb_update_valid = recovery_bp_update_valid && recovery_bp_update_taken;
    assign btb_update_pc = recovery_bp_update_pc;
    assign btb_update_target = ex_branch_actualTarget;


endmodule
