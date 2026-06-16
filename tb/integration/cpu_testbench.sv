`timescale 1ps/1ps

module cpu_testbench();
    parameter CLOCK_PERIOD = 100000;

    logic clk, reset;

    PipelinedCPU dut (.clk(clk), .reset(reset));

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


endmodule


