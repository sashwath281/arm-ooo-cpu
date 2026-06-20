`timescale 1ps/1ps

module and64(out, a, b);
    input logic [63:0] a, b;
    output logic [63:0] out;

    genvar i;

    generate 
        for(i = 0; i < 64; i++) begin: andLoop
            and #(50) g(out[i], a[i], b[i]);
        end
    
    endgenerate

endmodule
