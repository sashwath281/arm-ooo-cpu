`timescale 1ps/1ps

module cpu_testbench();
    parameter CLOCK_PERIOD = 100000;

    logic clk, reset;

    OoOCPU dut (.clk(clk), .reset(reset));

    // Force %t's to print in a nice format.
    initial $timeformat(-9, 2, " ns", 10);

    // Clock
    initial begin
        clk <= 0;
        forever #(CLOCK_PERIOD/2) clk <= ~clk;
    end 


    initial begin   

        // Reset CPU before running benchmark
        reset <= 1; 
        repeat(10) @(posedge clk);
        reset <= 0;


        $display("%t Running benchmark", $time);
        repeat(5000) @(posedge clk);


        $display("%t Benchmark is complete", $time);
        $stop;
    end 


    // Shadow architectural registers — always show current arch state
    logic [63:0] arch_X0, arch_X1, arch_X2, arch_X3, arch_X4, arch_X5, arch_X6, arch_X7, arch_X8, arch_X9, arch_X10, arch_X11, arch_X12, arch_X13, arch_X14, arch_X15, arch_X16, arch_X17, arch_X18, arch_X19, arch_X20, arch_X21, arch_X22, arch_X23, arch_X24, arch_X25, arch_X26, arch_X27, arch_X28, arch_X29, arch_X30, arch_X31;

    always_comb begin
        arch_X0 = dut.prf.regs[dut.rename.rat_inst.mapping[0]];
        arch_X1 = dut.prf.regs[dut.rename.rat_inst.mapping[1]];
        arch_X2 = dut.prf.regs[dut.rename.rat_inst.mapping[2]];
        arch_X3 = dut.prf.regs[dut.rename.rat_inst.mapping[3]];
        arch_X4 = dut.prf.regs[dut.rename.rat_inst.mapping[4]];
        arch_X5 = dut.prf.regs[dut.rename.rat_inst.mapping[5]];
        arch_X6 = dut.prf.regs[dut.rename.rat_inst.mapping[6]];
        arch_X7 = dut.prf.regs[dut.rename.rat_inst.mapping[7]];
        arch_X8 = dut.prf.regs[dut.rename.rat_inst.mapping[8]];
        arch_X9 = dut.prf.regs[dut.rename.rat_inst.mapping[9]];
        arch_X10 = dut.prf.regs[dut.rename.rat_inst.mapping[10]];
        arch_X11 = dut.prf.regs[dut.rename.rat_inst.mapping[11]];
        arch_X12 = dut.prf.regs[dut.rename.rat_inst.mapping[12]];
        arch_X13 = dut.prf.regs[dut.rename.rat_inst.mapping[13]];
        arch_X14 = dut.prf.regs[dut.rename.rat_inst.mapping[14]];
        arch_X15 = dut.prf.regs[dut.rename.rat_inst.mapping[15]];
        arch_X16 = dut.prf.regs[dut.rename.rat_inst.mapping[16]];
        arch_X17 = dut.prf.regs[dut.rename.rat_inst.mapping[17]];
        arch_X18 = dut.prf.regs[dut.rename.rat_inst.mapping[18]];
        arch_X19 = dut.prf.regs[dut.rename.rat_inst.mapping[19]];
        arch_X20 = dut.prf.regs[dut.rename.rat_inst.mapping[20]];
        arch_X21 = dut.prf.regs[dut.rename.rat_inst.mapping[21]];
        arch_X22 = dut.prf.regs[dut.rename.rat_inst.mapping[22]];
        arch_X23 = dut.prf.regs[dut.rename.rat_inst.mapping[23]];
        arch_X24 = dut.prf.regs[dut.rename.rat_inst.mapping[24]];
        arch_X25 = dut.prf.regs[dut.rename.rat_inst.mapping[25]];
        arch_X26 = dut.prf.regs[dut.rename.rat_inst.mapping[26]];
        arch_X27 = dut.prf.regs[dut.rename.rat_inst.mapping[27]];
        arch_X28 = dut.prf.regs[dut.rename.rat_inst.mapping[28]];
        arch_X29 = dut.prf.regs[dut.rename.rat_inst.mapping[29]];
        arch_X30 = dut.prf.regs[dut.rename.rat_inst.mapping[30]];
        arch_X31 = dut.prf.regs[dut.rename.rat_inst.mapping[31]];
    end

endmodule


