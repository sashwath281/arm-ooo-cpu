`timescale 1ps/1ps

module PipelinedCPU (clk, reset);
    input logic clk, reset;

    logic [63:0] pc, pcplus4, next_pc;
    logic pcAdder_cout;
    logic [63:0] pcAdder_carry;
    logic [31:0] instruction;
    logic [63:0] RegisterData1, RegisterData2;
    logic [63:0] alu_b, aluResult;
    logic [63:0] MemReadData, Writebackdata;
    logic [2:0] aluCtrl;
    logic negative, zero, overflow, carryout;
    logic [63:0] immExt, immShifted; 
    logic branch_taken;
    logic [63:0] branchlogic_next_pc;

    // Control Signals
    logic Reg2Loc, RegWrite, ALUSrc, MemWrite, MemRead, MemToReg, BranchUncond, BranchCond, FlagSet, 
          BranchReg, Link;
    logic [1:0] ALUOp, ImmSel;
	 
	 // Forwarding
	 logic [1:0] ForwardA;
	 logic [1:0] ForwardB;
	 logic [63:0] forwarded_A;
	 logic [63:0] forwarded_B;


    // Saved Flags
    logic savedNegative, savedOverflow;
    logic forwardNeg, forwardOver;
    logic useForward;

    // Mux outputs
    logic [4:0] write_reg, read_reg1, read_reg2;
    logic [63:0] write_data;

    // Pipeline helper wire
    logic pipeWriteEnable;
    assign pipeWriteEnable = 1'b1;

    // Branch prediction — IF stage
    logic predict_taken_if;
    logic btb_hit;
    logic [63:0] predict_target_if;
    logic [7:0] predict_bhr_snapshot;

    // Carried through IF/ID
    logic IFID_predict_taken;
    logic [63:0] IFID_predict_target;
    logic [7:0] IFID_bhr_snapshot;

    // Computed in ID
    logic mispredict;
    logic [63:0] branch_target_actual;
    logic take_prediction_if;
    logic IFID_Flush_unused;

    logic [63:0] predicted_next_pc;
    logic [63:0] corrected_next_pc;


    // I-Cache signals
    logic icache_ready;
    logic [31:0] icache_instruction;
    logic icache_mem_req;
    logic [63:0] icache_mem_addr;
    logic icache_mem_resp_valid;
    logic [255:0] icache_mem_resp_data;


    // Stall pipeline on cache miss
    logic PCWrite_hdu, IFID_Write_hdu;

    assign PCWrite   = PCWrite_hdu && icache_ready;
    assign IFID_Write = IFID_Write_hdu && icache_ready;


    // Control packing wires
    logic [31:0] IDEX_control_in32;
    logic [31:0] IDEX_control_out32;

    logic [31:0] EXMEM_control_in32;
    logic [31:0] EXMEM_control_out32;

    logic [31:0] MEMWB_control_in32;
    logic [31:0] MEMWB_control_out32;


    // IF/ID Pipeline Register Outputs

    logic [63:0] IFID_pc, IFID_pcplus4;
    logic [31:0] IFID_instruction;

    // ID/EX Pipeline Register Outputs

    logic [63:0] IDEX_pc, IDEX_pcplus4;
    logic [31:0] IDEX_instruction;

    logic [63:0] IDEX_RegisterData1, IDEX_RegisterData2;
    logic [63:0] IDEX_immExt, IDEX_immShifted;
    logic [4:0] IDEX_read_reg1, IDEX_read_reg2, IDEX_write_reg;

    logic IDEX_RegWrite;
    logic IDEX_ALUSrc;
    logic IDEX_MemWrite;
    logic IDEX_MemRead;
    logic IDEX_MemToReg;
    logic IDEX_FlagSet;
    logic IDEX_Link;
    logic [1:0] IDEX_ALUOp;
    logic [1:0] IDEX_ImmSel;


    // EX/MEM Pipeline Register Outputs
	 
    logic [63:0] EXMEM_aluResult, EXMEM_RegisterData2;
    logic [63:0] EXMEM_pcplus4;
    logic [4:0] EXMEM_write_reg;
    logic [31:0] EXMEM_instruction;

    logic EXMEM_RegWrite;
    logic EXMEM_MemWrite;
    logic EXMEM_MemRead;
    logic EXMEM_MemToReg;
    logic EXMEM_Link;


    // MEM/WB Pipeline Register Outputs

    logic [63:0] MEMWB_aluResult, MEMWB_MemReadData;
    logic [63:0] MEMWB_pcplus4;
    logic [31:0] MEMWB_instruction;

    logic [4:0] MEMWB_write_reg;

    logic MEMWB_RegWrite;
    logic MEMWB_MemToReg;
    logic MEMWB_Link;


    // Hazard / flush control
    logic PCWrite, IFID_Write, ControlBubble, IFID_Flush;
    logic [31:0] IFID_instruction_in;
    logic [31:0] IDEX_control_raw;



    // PHASE -1 

    // PC
    PC programCounter (.clk(clk), .reset(reset), .writeEnable(PCWrite), .next_pc(next_pc), .pc(pc));
    adder64 pcAdder (.sum(pcplus4),.cout(pcAdder_cout), .carry(pcAdder_carry), .a(pc), .b(64'd4), .cin(1'b0));


    // Instruction Memory
    icache instruction_cache (.clk(clk), .reset(reset), .pc(pc), .valid(1'b1), .instruction(instruction),
                              .ready(icache_ready), .mem_req(icache_mem_req), .mem_addr(icache_mem_addr),
                              .mem_resp_valid(icache_mem_resp_valid), .mem_resp_data(icache_mem_resp_data));
    

    mem_backend imem_backend (.clk(clk), .reset(reset), .req_valid(icache_mem_req), .req_addr(icache_mem_addr),
                              .resp_valid(icache_mem_resp_valid), .resp_data(icache_mem_resp_data));

    // gshare - direction predictor
    gshare branch_predictor (.clk(clk), .reset(reset), .predict_pc(pc), .predict_taken(predict_taken_if), .predict_bhr_snapshot(predict_bhr_snapshot),
                             .update_valid(gshare_update_valid), .update_pc(IFID_pc), .update_bhr(IFID_bhr_snapshot), .update_taken(branch_taken));
    
    
    // BTB - target predictor
    btb branch_target_buffer (.clk(clk), .reset(reset), .predict_pc(pc), .btb_hit(btb_hit), .predict_target(predict_target_if),
                              .update_valid(btb_update_valid), .update_pc(IFID_pc), .update_target(branch_target_actual)); 
    
    assign take_prediction_if = btb_hit & predict_taken_if;
    mux64_2to1 predicted_pc_mux (.a(pcplus4), .b(predict_target_if), .sel(take_prediction_if), .out(predicted_next_pc));

    
    // IF/ID Pipeline Registers

    register64 IFID_pc_reg (
        .q(IFID_pc),
        .d(pc),
        .writeEnable(IFID_Write),
        .clk(clk)
    );

    register64 IFID_pcplus4_reg (
        .q(IFID_pcplus4),
        .d(pcplus4),
        .writeEnable(IFID_Write),
        .clk(clk)
    );

    
    mux32_2to1 ifid_flush_mux (.a(instruction), .b(32'b0),
                               .sel(IFID_Flush), .out(IFID_instruction_in));


    register32 IFID_instruction_reg (
        .q(IFID_instruction),
        .d(IFID_instruction_in),
        .writeEnable(IFID_Write),
        .clk(clk),
        .reset(reset)
    );


    register1 IFID_predict_taken_reg (
        .q(IFID_predict_taken),
        .d(take_prediction_if),
        .writeEnable(IFID_Write),
        .clk(clk),
        .reset(reset)
    );

    register64 IFID_predict_target_reg (
        .q(IFID_predict_target),
        .d(predict_target_if),
        .writeEnable(IFID_Write),
        .clk(clk)
    );

    register8 IFID_bhr_snapshot_reg (
        .q(IFID_bhr_snapshot),
        .d(predict_bhr_snapshot),
        .writeEnable(IFID_Write),
        .clk(clk),
        .reset(reset)
    );


    // PHASE -2

    // Control
    Control control (.instruction(IFID_instruction), .RegWrite(RegWrite), .ALUSrc(ALUSrc), .MemWrite(MemWrite),
                     .MemRead(MemRead), .MemToReg(MemToReg), .BranchUncond(BranchUncond),
                     .BranchCond(BranchCond), .FlagSet(FlagSet), .BranchReg(BranchReg),
                     .Link(Link), .ALUOp(ALUOp), .ImmSel(ImmSel), .Reg2Loc(Reg2Loc));
    

    
    // Hazard Detection Unit
    HazardDetectionUnit hazardUnit (.IDEX_MemRead (IDEX_MemRead), .IDEX_write_reg (IDEX_write_reg),
                                    .IFID_read_reg1 (IFID_instruction[9:5]), .IFID_read_reg2 (IFID_instruction[20:16]),
                                    .branch_taken (branch_taken), .PCWrite (PCWrite_HDU), .IFID_Write (IFID_Write_HDU),
                                    .ControlBubble (ControlBubble), .IFID_Flush (IFID_Flush_unused));


    // Reg2Loc Mux
    mux5_2to1 reg2Loc_mux (.a(IFID_instruction[20:16]), .b(IFID_instruction[4:0]), .sel(Reg2Loc), .out(read_reg2));


    // BL instruction - Writes to X30
    mux5_2to1 bl_mux (.a(IFID_instruction[4:0]), .b(5'd30), .sel(Link), .out(write_reg));


    // BR instruction
    mux5_2to1 br_mux (.a(IFID_instruction[9:5]), .b(IFID_instruction[4:0]), .sel(BranchReg), .out(read_reg1));


    // Register File
    logic [63:0] regfileReadData1, regfileReadData2;
    logic ForwardWBA, ForwardWBB;

    regfile registerFile (.clk(clk), .ReadRegister1(read_reg1), .ReadRegister2(read_reg2), 
                          .WriteRegister(MEMWB_write_reg), .WriteData(write_data), .RegWrite(MEMWB_RegWrite),
                          .ReadData1(regfileReadData1), .ReadData2(regfileReadData2));
    
    WBForwardUnit wbForward(.MEMWB_write_reg(MEMWB_write_reg), .MEMWB_RegWrite(MEMWB_RegWrite), 
                            .read_reg1(read_reg1), .read_reg2(read_reg2), 
                            .ForwardWBA(ForwardWBA), .ForwardWBB(ForwardWBB));
    

    mux64_2to1 wb_MUX1 (.a(regfileReadData1), .b(write_data), .sel(ForwardWBA), .out(RegisterData1));
    mux64_2to1 wb_MUX2 (.a(regfileReadData2), .b(write_data), .sel(ForwardWBB), .out(RegisterData2));


    // Sign Extender
    signextend imm(.instruction(IFID_instruction), .ImmSel(ImmSel), .imm64(immExt));


    // Shift Left 2
    shiftLeft SL(.in(immExt), .out(immShifted));

    logic cbzEq, cbz_not_xzr, cbzForward, cbzForwardfinal;
    logic [63:0] cbzRegisterData2;

    Equal5  cbz_cmp (.a(IDEX_write_reg), .b(read_reg2), .eq(cbzEq));
    NotXZR5 cbz_xzr (.reg_num(IDEX_write_reg), .not_xzr(cbz_not_xzr));

    and #50 cbzAnd1 (cbzForward,  IDEX_RegWrite, cbz_not_xzr);
    and #50 cbzAnd2 (cbzForwardfinal, cbzForward,   cbzEq);

    mux64_2to1 cbz_mux (.a(RegisterData2), .b(aluResult), 
                        .sel(cbzForwardfinal), .out(cbzRegisterData2));


    // Branch Logic
    and #(50) flagForward (useForward, IDEX_FlagSet, BranchCond);
    mux2to1 negativeForwardMUX (.in0(savedNegative), .in1(negative), .sel(useForward), .out(forwardNeg));
    mux2to1 overflowForwardMUX (.in0(savedOverflow), .in1(overflow), .sel(useForward), .out(forwardOver));

    BranchLogic branchLogic (.instruction(IFID_instruction), .BranchUncond(BranchUncond), 
                             .BranchCond(BranchCond), .BranchReg(BranchReg),
                             .savedNegative(forwardNeg), .savedOverflow(forwardOver),
                             .pc(IFID_pc), .branchImm(immShifted), .RegisterData1(RegisterData1),
                             .RegisterData2(cbzRegisterData2), .pcplus4(pcplus4), .next_pc(branchlogic_next_pc),
                             .branch_taken(branch_taken));
    
    
    logic [63:0] pc_plus_imm;
    assign pc_plus_imm = IFID_pc + immShifted;

    mux64_2to1 branch_target_mux(.a(pc_plus_imm), .b(RegisterData1), .sel(BranchReg), .out(branch_target_actual));

    logic is_branch_in_id;
    assign is_branch_in_id = BranchUncond | BranchCond | BranchReg;

    mux64_2to1 corrected_pc_mux(.a(IFID_pcplus4), .b(branch_target_actual), .sel(branch_taken), .out(corrected_next_pc));


    assign mispredict = is_branch_in_id &&((branch_taken != IFID_predict_taken) || (branch_taken && IFID_predict_taken && (branch_target_actual != IFID_predict_target)));
    assign IFID_Flush = mispredict;

    mux64_2to1 final_pc_mux(.a(predicted_next_pc), .b(corrected_next_pc), .sel(mispredict), .out(next_pc));


    logic gshare_update_valid;
    logic btb_update_valid;

    assign gshare_update_valid = is_branch_in_id && BranchCond;   // conditional branches only
    assign btb_update_valid    = is_branch_in_id && branch_taken; // taken branches only
    
    // ID/EX Pipeline Registers

    register64 IDEX_pc_reg (
        .q(IDEX_pc),
        .d(IFID_pc),
        .writeEnable(pipeWriteEnable),
        .clk(clk)
    );

    register64 IDEX_pcplus4_reg (
        .q(IDEX_pcplus4),
        .d(IFID_pcplus4),
        .writeEnable(pipeWriteEnable),
        .clk(clk)
    );

    register32 IDEX_instruction_reg (
        .q(IDEX_instruction),
        .d(IFID_instruction),
        .writeEnable(pipeWriteEnable),
        .clk(clk),
        .reset(reset)
    );

    register64 IDEX_RegisterData1_reg (
        .q(IDEX_RegisterData1),
        .d(RegisterData1),
        .writeEnable(pipeWriteEnable),
        .clk(clk)
    );

    register64 IDEX_RegisterData2_reg (
        .q(IDEX_RegisterData2),
        .d(RegisterData2),
        .writeEnable(pipeWriteEnable),
        .clk(clk)
    );

    register64 IDEX_immExt_reg (
        .q(IDEX_immExt),
        .d(immExt),
        .writeEnable(pipeWriteEnable),
        .clk(clk)
    );

    register64 IDEX_immShifted_reg (
        .q(IDEX_immShifted),
        .d(immShifted),
        .writeEnable(pipeWriteEnable),
        .clk(clk)
    );

    register5 IDEX_read_reg1_reg (
        .q(IDEX_read_reg1),
        .d(read_reg1),
        .writeEnable(pipeWriteEnable),
        .clk(clk),
        .reset(reset)
    );

    register5 IDEX_read_reg2_reg (
        .q(IDEX_read_reg2),
        .d(read_reg2),
        .writeEnable(pipeWriteEnable),
        .clk(clk),
        .reset(reset)
    );

    register5 IDEX_write_reg_reg (
        .q(IDEX_write_reg),
        .d(write_reg),
        .writeEnable(pipeWriteEnable),
        .clk(clk),
        .reset(reset)
    );

    register32 IDEX_control_reg (
        .q(IDEX_control_out32),
        .d(IDEX_control_in32),
        .writeEnable(pipeWriteEnable),
        .clk(clk),
        .reset(reset)
    );



    // PHASE -3
	 
    // Forwarding Unit

    ForwardingUnit forwarding_unit (
        .IDEX_read_reg1(IDEX_read_reg1),
        .IDEX_read_reg2(IDEX_read_reg2),

        .EXMEM_write_reg(EXMEM_write_reg),
        .EXMEM_RegWrite(EXMEM_RegWrite),

        .MEMWB_write_reg(MEMWB_write_reg),
        .MEMWB_RegWrite(MEMWB_RegWrite),

        .ForwardA(ForwardA),
        .ForwardB(ForwardB)
    );

    // Forwarding muxes

    mux64_4to1 forwardA_mux (.a(IDEX_RegisterData1), .b(write_data),         
                             .c(EXMEM_aluResult), .d(64'b0), .sel(ForwardA),
                             .out(forwarded_A));

    mux64_4to1 forwardB_mux (.a(IDEX_RegisterData2), .b(write_data),  
                             .c(EXMEM_aluResult), .d(64'b0), .sel(ForwardB),
                             .out(forwarded_B));


    // ALU Control
    ALUControl aluControlUnit (.ALUOp(IDEX_ALUOp), .op11(IDEX_instruction[31:21]), .ALUCtrl(aluCtrl));


    // ALUSrc Mux 
    mux64_2to1 aluSrc_mux(.a(forwarded_B), .b(IDEX_immExt), .sel(IDEX_ALUSrc), .out(alu_b));


    // ALU
    alu ALU (.A(forwarded_A), .B(alu_b), .cntrl(aluCtrl), .result(aluResult),
             .negative(negative), .zero(zero), .overflow(overflow),
             .carry_out(carryout));


    // Flag Register
    register1 neg_ff (.q(savedNegative), .d(negative), .writeEnable(IDEX_FlagSet), .clk(clk), .reset(reset));
    register1 over_ff(.q(savedOverflow), .d(overflow), .writeEnable(IDEX_FlagSet), .clk(clk), .reset(reset));


    // EX/MEM Pipeline Registers

    register64 EXMEM_aluResult_reg (
        .q(EXMEM_aluResult),
        .d(aluResult),
        .writeEnable(pipeWriteEnable),
        .clk(clk)
    );

    register64 EXMEM_RegisterData2_reg (
        .q(EXMEM_RegisterData2),
        .d(forwarded_B),
        .writeEnable(pipeWriteEnable),
        .clk(clk)
    );

    register64 EXMEM_pcplus4_reg (
        .q(EXMEM_pcplus4),
        .d(IDEX_pcplus4),
        .writeEnable(pipeWriteEnable),
        .clk(clk)
    );

    register32 EXMEM_instruction_reg (
        .q(EXMEM_instruction),
        .d(IDEX_instruction),
        .writeEnable(pipeWriteEnable),
        .clk(clk),
        .reset(reset)
    );

    register5 EXMEM_write_reg_reg (
        .q(EXMEM_write_reg),
        .d(IDEX_write_reg),
        .writeEnable(pipeWriteEnable),
        .clk(clk),
        .reset(reset)
    );

    register32 EXMEM_control_reg (
        .q(EXMEM_control_out32),
        .d(EXMEM_control_in32),
        .writeEnable(pipeWriteEnable),
        .clk(clk),
        .reset(reset)
    );


    // PHASE -4

    // Data Memory
    datamem dataMemory (.address(EXMEM_aluResult), .write_enable(EXMEM_MemWrite), .read_enable(EXMEM_MemRead),
                        .write_data(EXMEM_RegisterData2), .clk(clk), .xfer_size(4'd8),
                        .read_data(MemReadData));



    // MEM/WB Pipeline Registers

    register64 MEMWB_aluResult_reg (
        .q(MEMWB_aluResult),
        .d(EXMEM_aluResult),
        .writeEnable(pipeWriteEnable),
        .clk(clk)
    );

    register64 MEMWB_MemReadData_reg (
        .q(MEMWB_MemReadData),
        .d(MemReadData),
        .writeEnable(pipeWriteEnable),
        .clk(clk)
    );

    register64 MEMWB_pcplus4_reg (
        .q(MEMWB_pcplus4),
        .d(EXMEM_pcplus4),
        .writeEnable(pipeWriteEnable),
        .clk(clk)
    );

    register32 MEMWB_instruction_reg (
        .q(MEMWB_instruction),
        .d(EXMEM_instruction),
        .writeEnable(pipeWriteEnable),
        .clk(clk),
        .reset(reset)
    );

    register5 MEMWB_write_reg_reg (
        .q(MEMWB_write_reg),
        .d(EXMEM_write_reg),
        .writeEnable(pipeWriteEnable),
        .clk(clk),
        .reset(reset)
    );

    register32 MEMWB_control_reg (
        .q(MEMWB_control_out32),
        .d(MEMWB_control_in32),
        .writeEnable(pipeWriteEnable),
        .clk(clk),
        .reset(reset)
    );


    // Mem2Reg mux
    mux64_2to1 mem2Reg_mux (.a(MEMWB_aluResult), .b(MEMWB_MemReadData), .sel(MEMWB_MemToReg), .out(Writebackdata));
    

    // BL instruction - Writes PC+4 as data
    mux64_2to1 bl2_mux (.a(Writebackdata), .b(MEMWB_pcplus4), .sel(MEMWB_Link), .out(write_data));


    // ID/EX control signal packing
    assign IDEX_control_raw[0] = RegWrite;
    assign IDEX_control_raw[1] = ALUSrc;
    assign IDEX_control_raw[2] = MemWrite;
    assign IDEX_control_raw[3] = MemRead;
    assign IDEX_control_raw[4] = MemToReg;
    assign IDEX_control_raw[5] = FlagSet;
    assign IDEX_control_raw[6] = Link;
    assign IDEX_control_raw[8:7] = ALUOp;
    assign IDEX_control_raw[10:9] = ImmSel;
    assign IDEX_control_raw[31:11] = 21'd0;

    // Bubble: zero out control signals on load-use stall (NOP into EX)
    mux32_2to1 control_bubble_mux (.a(IDEX_control_raw), .b(32'b0),
                                   .sel(ControlBubble), .out(IDEX_control_in32));

    assign IDEX_RegWrite = IDEX_control_out32[0];
    assign IDEX_ALUSrc = IDEX_control_out32[1];
    assign IDEX_MemWrite = IDEX_control_out32[2];
    assign IDEX_MemRead = IDEX_control_out32[3];
    assign IDEX_MemToReg = IDEX_control_out32[4];
    assign IDEX_FlagSet = IDEX_control_out32[5];
    assign IDEX_Link = IDEX_control_out32[6];
    assign IDEX_ALUOp = IDEX_control_out32[8:7];
    assign IDEX_ImmSel = IDEX_control_out32[10:9];


    // EX/MEM packing connections

    assign EXMEM_control_in32[0] = IDEX_RegWrite;
    assign EXMEM_control_in32[1] = IDEX_MemWrite;
    assign EXMEM_control_in32[2] = IDEX_MemRead;
    assign EXMEM_control_in32[3] = IDEX_MemToReg;
    assign EXMEM_control_in32[4] = IDEX_Link;
    assign EXMEM_control_in32[31:5] = 27'd0;

    assign EXMEM_RegWrite = EXMEM_control_out32[0];
    assign EXMEM_MemWrite = EXMEM_control_out32[1];
    assign EXMEM_MemRead = EXMEM_control_out32[2];
    assign EXMEM_MemToReg = EXMEM_control_out32[3];
    assign EXMEM_Link = EXMEM_control_out32[4];


    // MEM/WB packing connections

    assign MEMWB_control_in32[0] = EXMEM_RegWrite;
    assign MEMWB_control_in32[1] = EXMEM_MemToReg;
    assign MEMWB_control_in32[2] = EXMEM_Link;
    assign MEMWB_control_in32[31:3] = 29'd0;

    assign MEMWB_RegWrite = MEMWB_control_out32[0];
    assign MEMWB_MemToReg = MEMWB_control_out32[1];
    assign MEMWB_Link = MEMWB_control_out32[2];



endmodule