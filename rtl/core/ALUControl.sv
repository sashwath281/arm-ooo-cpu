`timescale 1ps/1ps

module ALUControl(ALUOp, op11, ALUCtrl);
    input  logic [1:0]  ALUOp;
    input  logic [10:0] op11;
    output logic [2:0]  ALUCtrl;

    always_comb begin
        
        case(ALUOp)
            2'b00: ALUCtrl = 3'b010;       // ADD (ADDI, LDUR, STUR)
            2'b01: ALUCtrl = 3'b010;       // ADD (branches)
            2'b10: begin                    // R-Type (checking Opcode)

                case(op11)
                    11'b10101011000: ALUCtrl = 3'b010;     // ADDS to ADD
                    11'b11101011000: ALUCtrl = 3'b011;     // SUBS to SUB

                    default: ALUCtrl = 3'bXXX;
                endcase
            
            end 
            default: ALUCtrl = 3'bXXX;
        
        endcase
    end 


endmodule 
