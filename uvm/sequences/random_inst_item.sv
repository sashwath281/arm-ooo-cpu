`timescale 1ps/1ps

// creates the randomm instruction which feeds into the DUT to test random cases. 
// We find out how our DUT reacts to any instruction rather than specific ones we write. 
class random_inst_item extends uvm_sequence_item;

    `uvm_object_utils(random_inst_item)        // Register as object with UVM Factory

    // A named set of possible instructions (for now, will change later)
    // The solver will pick one of these five named values randomly
    typedef enum {ADDI, ADDS, SUBS, CBZ, B} inst_type_e;


    rand inst_type_e inst_type;     // One of the instructions
    rand bit [4:0] rd;              // Destinatoon Reg
    rand bit [4:0] rn;              // First Source Reg
    rand bit [4:0] rm;              // Second Source Reg
    rand bit [11:0] imm12;          // I-Type Immediate
    rand bit [18:0] imm19;          // CBZ Type Immediate
    rand bit [25:0] imm26;          // B Type Immediate


    bit [31:0] instruction;         // Full instruction opcode

    // Constraint 1: Registers (Rd, Rn, Rm) should only be between 0 and 30
    // Avoids X31 (XZR) and other impossible Reg values
    constraint c_valid_registers{
        rd inside {[0:30]};
        rn inside {[0:30]};
        rm inside {[0:30]};
    }

    // Constraint 2: Each instruction type must only be of the given percentages
    // These percentages are realistic mixes of how instructions are in actual program.
    constraint c_type_distribution {
        inst_type dist{
            ADDI := 40, ADDS := 20, SUBS := 20, CBZ := 15, B := 5
        };
    }

    // Construction: Object
    function new(string name = "random_inst_item");
        super.new(name);
    endfunction

    // Making the instruction for each randomized instruction type. 
    // Using the respective opcode and adding the random Reg and Immidiate Values. 
    function void encode();
        case (inst_type)
            ADDI: instruction = {10'b1001000100, imm12, rn, rd};
            ADDS: instruction = {11'b10101011000, rm, 6'b0, rn, rd};
            SUBS: instruction = {11'b11101011000, rm, 6'b0, rn, rd};
            CBZ: instruction = {8'b10110100, imm19, rd};
            B: instruction = {6'b000101, imm26};
        endcase

    endfunction

    // Return instruction type, reg values, and full instruction as a string
    virtual function string convert2string();
        return $sformatf("type=%s rd=%0d rn=%0d rm=%0d inst=0x%h",
                         inst_type.name(), rd, rn, rm, instruction);
    endfunction

endclass