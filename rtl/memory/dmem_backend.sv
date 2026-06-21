`timescale 1ps/1ps

module dmem_backend (clk, reset, read_req, read_addr, read_resp_valid, read_resp_data, write_req, write_addr, write_data, write_done);
    input  logic clk;
    input  logic reset;

    // Read request (cache miss to fetch block)
    input  logic read_req;
    input  logic [63:0] read_addr;
    output logic read_resp_valid;
    output logic [255:0] read_resp_data;

    // Write request (dirty eviction to writeback)
    input  logic write_req;
    input  logic [63:0] write_addr;
    input  logic [255:0] write_data;
    output logic write_done;


    // Read channel — 10 cycle latency
    logic [3:0] rd_counter;
    logic rd_busy;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            rd_counter <= 4'd0;
            rd_busy <= 1'b0;
            read_resp_valid <= 1'b0;
            read_resp_data  <= 256'd0;
        end

        else begin
            read_resp_valid <= 1'b0;

            if (!rd_busy && read_req) begin
                rd_busy <= 1'b1;
                rd_counter <= 4'd1;
            end

            else if (rd_busy) begin
                if (rd_counter == 4'd10) begin
                    read_resp_data <= 256'hDEAD_BEEF;  // the placeholder
                    read_resp_valid <= 1'b1;
                    rd_busy <= 1'b0;
                    rd_counter <= 4'd0;
                end

                else begin
                    rd_counter <= rd_counter + 4'd1;
                end
            end
        end
    end

    // Write channel — 1 cycle
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            write_done <= 1'b0;
        else
            write_done <= write_req;
    end

endmodule