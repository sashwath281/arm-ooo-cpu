`timescale 1ps/1ps

module physicalRegFile (clk, reset, read_phys_reg1, read_phys_reg2, read_data1, read_data2, write_valid, write_phys_reg, write_data);
    input logic clk;
    input logic reset;

    // Read ports
    input logic [5:0] read_phys_reg1;               // physical reg for first source
    input logic [5:0] read_phys_reg2;               // physical reg for second source
    output logic [63:0] read_data1;                 // data stored in phys_reg1
    output logic [63:0] read_data2;                 // data stored in phys_reg2

    // Write port (for CDB)
    input logic write_valid;                        // Do we have a destination? (STUR, CBZ)
    input logic [5:0] write_phys_reg;               // physical reg for destination register
    input logic [63:0] write_data;                  // data stored in phys_reg

    // Storage
    logic [63:0] regs [0:63];                       // 64 entries of registers each having 64 bits of data. 


    // Read — combinational
    assign read_data1 = regs[read_phys_reg1];
    assign read_data2 = regs[read_phys_reg2];

    // Runs at 0 to clear the array out
    integer i;

    initial begin
        for (i = 0; i < 64; i++)
            regs[i] = 64'd0;
    end


    // Write — sequential
    always @(posedge clk) begin
        if (write_valid)
            regs[write_phys_reg] <= write_data;
    end
  

endmodule