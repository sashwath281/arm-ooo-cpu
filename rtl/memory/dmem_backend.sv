`timescale 1ps/1ps

module dmem_backend(
    input logic clk,
    input logic reset,

    // Read request (cache miss to fetch block)
    input logic req_valid,
    input logic req_enable,
    input logic [63:0] req_addr,
    input logic [63:0] req_write_data,

    output logic resp_valid,
    output logic [255:0] resp_data);


    // Data memory - 1024 doublewords = 8KB data space
    logic [63:0] mem [0:1023];
    string data_file;


    // Word (doubleword) index from block-aligned byte address
    logic [9:0] baseDword;
    logic [63:0] saved_addr;
    assign baseDword = saved_addr[12:3];   // divide by 8 (each doubleword = 8 bytes)

    logic [3:0] counter;
    logic busy;
    logic saved_enable;
    logic [63:0] saved_write_data;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 4'd0;
            busy <= 1'b0;
            saved_addr <= 64'd0;
            resp_valid <= 1'b0;
            resp_data <= 256'd0;

            for(int i = 0; i < 1024; i = i + 1)
                mem[i] <= 64'b0;
        end

        else begin
            resp_valid <= 1'b0;

            if (!busy && req_valid) begin
                busy <= 1'b1;
                saved_addr <= req_addr;
                saved_enable <= req_enable;
                saved_write_data <= req_write_data;
                counter <= 4'd1;
            end

            else if (busy) begin
                if (counter == 4'd10) begin
                    if (saved_enable) begin
                        // store the doubleword into memory
                        mem[baseDword] <= saved_write_data;
                        resp_valid <= 1'b1;     // resp_data is don't-care on a write; leaving as-is
                    end

                    else begin
                        // return the full 256-bit block (4 doublewords)
                        resp_data <= { mem[baseDword+3], 
                                       mem[baseDword+2],
                                       mem[baseDword+1], 
                                       mem[baseDword+0]};
                        resp_valid <= 1'b1;
                    end

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