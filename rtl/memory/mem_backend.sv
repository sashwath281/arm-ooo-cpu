`timescale 1ps/1ps

module mem_backend (
    input logic clk,
    input logic reset,

    input logic req_valid,                // I-cache wants memory.
    input logic [63:0] req_addr,          // starting byte address it wants 

    output logic resp_valid,              // data, take it
    output logic [255:0] resp_data);      // 256 bits = 32 bytes = one cache block


    // 1024 words is 4KB instruction space
    logic [31:0] mem [0:1023];

    // Load test program
    // Zero everything out. If only X instructions then rest 1024-X instructions must be 0. (or X)
    // initial begin
    //      for (int i = 0; i < 1024; i++)
    //          mem[i] = 32'b0;
    //      $readmemb("sw/tests/test01_AddiB.arm", mem);        // Loads binary text file
    // end

    // Using plausargs to allow user to specify program file on command line.  If not specified, default to whatever we want (benchmarks)
    string program_file; 
    initial begin
        for(int i = 0; i < 1024; i++)
            mem[i] = 32'b0; 
        
        if($value$plusargs("PROGRAM=%s", program_file))    // Built-in SV task
            $readmemb(program_file, mem);
        else
            $readmemb("sw/tests/test06_BlBr.arm", mem);
    end


    // 10-cycle latency FSM
    logic [3:0] counter;        // counts cycle since request came in
    logic busy;                 // 1 = cuurently part of a request
    logic [63:0] saved_addr;    // latched copy of the requested address

    
    // Word index from byte address
    logic [9:0] baseWord;
    assign baseWord = saved_addr[11:2];  // divide by 4

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 4'd0;
            busy <= 1'b0;
            saved_addr <= 64'd0;
            resp_valid <= 1'b0;
            resp_data <= 256'd0;
        end

        else begin
            resp_valid <= 1'b0;  // default to 0 every cycle.

            if (!busy && req_valid) begin
                busy <= 1'b1;
                saved_addr <= req_addr;
                counter <= 4'd1;
            end

            else if (busy) begin
                if (counter == 4'd10) begin
                    resp_data <= {mem[baseWord + 7],      // MSB first
                                  mem[baseWord + 6],
                                  mem[baseWord + 5],
                                  mem[baseWord + 4],
                                  mem[baseWord + 3],
                                  mem[baseWord + 2],
                                  mem[baseWord + 1],
                                  mem[baseWord + 0]};     // LSB last
                    
                    resp_valid <= 1'b1;
                    busy <= 1'b0;
                    counter <= 4'd0;
                end
                
                else begin
                    counter <= counter + 4'd1;
                end
            end
        end
    end

endmodule