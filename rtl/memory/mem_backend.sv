`timescale 1ps/1ps

module mem_backend (clk, reset, req_valid, req_addr, resp_valid, resp_data);
    input  logic clk;
    input  logic reset;

    // Request interface (from cache)
    input  logic req_valid;
    input  logic [63:0] req_addr;

    // Response interface (to cache)
    output logic resp_valid;
    output logic [255:0] resp_data;


    // Fake memory: just returns addr-derived data after 10 cycles
    logic [3:0] counter;
    logic busy;
    logic [63:0] saved_addr;


    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            counter    <= 4'd0;
            busy       <= 1'b0;
            saved_addr <= 64'd0;
            resp_valid <= 1'b0;
            resp_data  <= 256'd0;
        end

        else begin
            resp_valid <= 1'b0;

            if (!busy && req_valid) begin
                busy       <= 1'b1;
                saved_addr <= req_addr;
                counter    <= 4'd1;
            end

            else if (busy) begin
                if (counter == 4'd10) begin
                    // Return a fake block: 8 instructions derived from address
                    resp_data <= {
                        saved_addr[31:0],           // word 7
                        saved_addr[31:0] + 32'd7,   // word 6
                        saved_addr[31:0] + 32'd6,   // word 5
                        saved_addr[31:0] + 32'd5,   // word 4
                        saved_addr[31:0] + 32'd4,   // word 3
                        saved_addr[31:0] + 32'd3,   // word 2
                        saved_addr[31:0] + 32'd2,   // word 1
                        saved_addr[31:0] + 32'd1    // word 0
                    };

                    resp_valid <= 1'b1;
                    busy       <= 1'b0;
                    counter    <= 4'd0;
                end

                else begin
                    counter <= counter + 4'd1;
                end
            end
        end
    end

endmodule