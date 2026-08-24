`timescale 1ps/1ps


// legv8_iss — LEGv8 Instruction Set Simulator (Golden Reference)
// Models ONLY the instructions
// ADDI, ADDS, SUBS, CBZ, B
//
// NOT modeled (matches known CPU RTL gaps):
//   ADD/SUB (non-S variants — RegWrite never fires for these)
//   AND/ORR (RegWrite never fires for these either)
//   LDUR/STUR (no D-Cache yet)
//   BL/BR (BL disabled in decode)
//   B.LT (NZCV renaming not implemented)

module legv8_iss #(parameter string PROGRAM_FILE = "sw/tests/test01_AddiB.arm")(
    input logic clk,
    input logic reset,
    input logic step,

    output logic committedValid,
    output logic [4:0] committedArchReg,
    output logic [63:0]committedData,
    output logic [63:0] committedPC,
    output logic done);

    logic [31:0] instr_mem [0:1023];
    string program_file;

    initial begin
        for (int i = 0; i < 1024; i++)
            instr_mem[i] = 32'b0;

        if ($value$plusargs("ISS_PROGRAM=%s", program_file))
            $readmemb(program_file, instr_mem);
        else
            $readmemb(PROGRAM_FILE, instr_mem);
    
    end

    logic [63:0] regfile [0:31];             // X0-X30, X31 = XZR
    logic [63:0] pc;


    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pc <= 64'd0;
            for (int i = 0; i < 32; i++)
                regfile[i] <= 64'd0;
            
            committedValid <= 1'b0;
            done <= 1'b0;
        end
    end

    // Decode fields
    logic [31:0] instruction;
    logic [10:0] op11;
    logic [9:0] op10;
    logic [7:0] op8;
    logic [5:0] op6;
    logic [4:0] rd, rn, rm;
    logic [11:0] imm12;
    logic [18:0] imm19;
    logic [25:0] imm26;
    logic [63:0] zero_ext_imm12, sign_ext_imm19, sign_ext_imm26;


    assign instruction = instr_mem[pc[11:2]];
    assign op11 = instruction[31:21];
    assign op10 = instruction[31:22];
    assign op8 = instruction[31:24];
    assign op6 = instruction[31:26];
    assign rd = instruction[4:0];
    assign rn = instruction[9:5];
    assign rm = instruction[20:16];
    assign imm12 = instruction[21:10];
    assign imm19 = instruction[23:5];
    assign imm26 = instruction[25:0];

    assign zero_ext_imm12 = {52'b0, imm12};                     // ADDI imm is unsigned
    assign sign_ext_imm19 = {{43{imm19[18]}}, imm19, 2'b00};    // CBZ offset, shifted by 2
    assign sign_ext_imm26 = {{38{imm26[25]}}, imm26, 2'b00};    // B offset, shifted by 2


    function automatic logic [63:0] read_reg(logic [4:0] r);
        if (r == 5'd31) 
            return 64'd0;       // XZR
        
        return regfile[r];
    endfunction

    always_ff @(posedge clk) begin
        committedValid <= 1'b0;

        if (!reset && step && !done) begin

            if (op10 == 10'b1001000100) begin
                // ADDI
                if (rd != 5'd31)
                    regfile[rd] <= read_reg(rn) + zero_ext_imm12;
                committedValid <= 1'b1;
                committedArchReg <= rd;
                committedData <= read_reg(rn) + zero_ext_imm12;
                committedPC <= pc;
                pc <= pc + 64'd4;
            end

            else if (op11 == 11'b10101011000) begin
                // ADDS
                if (rd != 5'd31)
                    regfile[rd] <= read_reg(rn) + read_reg(rm);
                committedValid <= 1'b1;
                committedArchReg <= rd;
                committedData <= read_reg(rn) + read_reg(rm);
                committedPC <= pc;
                pc <= pc + 64'd4;
            end

            else if (op11 == 11'b11101011000) begin
                // SUBS
                if (rd != 5'd31)
                    regfile[rd] <= read_reg(rn) - read_reg(rm);
                committedValid <= 1'b1;
                committedArchReg <= rd;
                committedData <= read_reg(rn) - read_reg(rm);
                committedPC <= pc;
                pc <= pc + 64'd4;
            end
            
            else if (op8 == 8'b10110100) begin
                // CBZ — tested register is at instruction[4:0] (Reg2Loc=1)
                committedValid <= 1'b0;     // branch, no reg write
                committedPC <= pc;
                
                if (read_reg(instruction[4:0]) == 64'd0)
                    pc <= pc + sign_ext_imm19;
                else
                    pc <= pc + 64'd4;
            end
            
            else if (op6 == 6'b000101) begin
                // B — unconditional
                committedValid <= 1'b0;
                committedPC <= pc;
                pc <= pc + sign_ext_imm26;
            end
           
            else if (instruction == 32'b0) begin
                // zero instruction = end of program
                done <= 1'b1;
                committedValid <= 1'b0;
            end
            
            else begin
                // Unmodeled instruction (ADD/SUB/AND/ORR/LDUR/STUR/etc.)
                // Advance PC, don't commit — matches CPU not writing back either
                committedValid <= 1'b0;
                pc <= pc + 64'd4;
            end
        end
    end


endmodule