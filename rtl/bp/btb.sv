module btb(clk, reset, predict_pc, btb_hit, predict_target, update_valid, update_pc, update_target);
    input  logic clk;
    input  logic reset;

    // Predict interface - used in IF stage every cycle
    input  logic [63:0]  predict_pc;
    output logic btb_hit;
    output logic [63:0]  predict_target;

    // Update interface - when branch resolves at EX stage
    input  logic update_valid;
    input  logic [63:0]  update_pc;
    input  logic [63:0]  update_target;


    logic [55:0]  tag_array    [0:63];
    logic [63:0]  target_array [0:63];
    logic         valid_array  [0:63];


    logic [5:0]   predict_index;
    logic [55:0]  predict_tag;

    assign predict_index = predict_pc[7:2];
    assign predict_tag   = predict_pc[63:8];

    assign btb_hit = valid_array[predict_index] && (tag_array[predict_index] == predict_tag);

    assign predict_target = target_array[predict_index];

    // Update path
    logic [5:0]   update_index;
    logic [55:0]  update_tag;

    assign update_index = update_pc[7:2];
    assign update_tag   = update_pc[63:8];

    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            for (int i = 0; i < 64; i++) begin
                valid_array[i]  <= 1'b0;
                tag_array[i]    <= '0;
                target_array[i] <= '0;
            end
        end

        else if (update_valid) begin
            valid_array[update_index]  <= 1'b1;
            tag_array[update_index]    <= update_tag;
            target_array[update_index] <= update_target;
        end
    end

endmodule