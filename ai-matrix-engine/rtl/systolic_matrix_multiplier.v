//=============================================================================
// 1. Processing Element (PE) - Signed Multiplier + Accumulator
//=============================================================================
module pe #(
    parameter integer IN_WIDTH  = 8,
    parameter integer ACC_WIDTH = 32
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         clr_acc,
    input  wire                         enable,
    input  wire signed [IN_WIDTH-1:0]  act_in,
    input  wire signed [IN_WIDTH-1:0]  wgt_in,
    output reg  signed [ACC_WIDTH-1:0] acc_out
);

    wire signed [ACC_WIDTH-1:0] mult_product;
    
    assign mult_product = $signed(act_in) * $signed(wgt_in);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_out <= 32'sd0;
        end else if (clr_acc) begin
            acc_out <= enable ? mult_product : 32'sd0;
        end else if (enable) begin
            acc_out <= acc_out + mult_product;
        end
    end

endmodule


//=============================================================================
// 2. Output Post-Processing Block (Dynamic Bit-Width Saturation)
//=============================================================================
module post_processor #(
    parameter integer ACC_WIDTH = 32,
    parameter integer OUT_WIDTH = 16
)(
    input  wire signed [ACC_WIDTH-1:0] acc_in,
    input  wire signed [7:0]           shift_amount,
    output reg  signed [OUT_WIDTH-1:0] data_out
);

    wire signed [ACC_WIDTH-1:0] shifted_acc;
    
    assign shifted_acc = $signed(acc_in) >>> $signed(shift_amount);

    wire signed [ACC_WIDTH-1:0] max_pos = (32'sd1 <<< (OUT_WIDTH - 1)) - 32'sd1;
    wire signed [ACC_WIDTH-1:0] min_neg = -(32'sd1 <<< (OUT_WIDTH - 1));

    always @(*) begin
        if ($signed(shifted_acc) > max_pos) begin
            data_out = max_pos[OUT_WIDTH-1:0];
        end else if ($signed(shifted_acc) < min_neg) begin
            data_out = min_neg[OUT_WIDTH-1:0];
        end else begin
            data_out = shifted_acc[OUT_WIDTH-1:0];
        end
    end

endmodule


//=============================================================================
// 3. Top-Level Parameterized Matrix Multiplier Engine (Pure Verilog-2001)
//=============================================================================
module systolic_matrix_multiplier #(
    parameter integer M          = 4,
    parameter integer N          = 4,
    parameter integer IN_WIDTH   = 8,
    parameter integer ACC_WIDTH  = 32,
    parameter integer OUT_WIDTH  = 16
)(
    input  wire clk,
    input  wire rst_n,
    
    input  wire clr_acc,
    input  wire mac_enable,
    input  wire [7:0] shift_amount,
    
    input  wire signed [M*IN_WIDTH-1:0]    act_matrix_flat,
    input  wire signed [N*IN_WIDTH-1:0]    wgt_matrix_flat,
    output wire signed [M*N*OUT_WIDTH-1:0]  out_matrix_flat
);

    wire signed [ACC_WIDTH-1:0] raw_accumulators [0:M-1][0:N-1];

    wire signed [7:0] signed_shift;
    assign signed_shift = $signed(shift_amount);

    genvar i, j;
    generate
        for (i = 0; i < M; i = i + 1) begin : ROW
            for (j = 0; j < N; j = j + 1) begin : COL
                
                wire signed [IN_WIDTH-1:0] act_elem = $signed(act_matrix_flat[i*IN_WIDTH +: IN_WIDTH]);
                wire signed [IN_WIDTH-1:0] wgt_elem = $signed(wgt_matrix_flat[j*IN_WIDTH +: IN_WIDTH]);

                pe #(
                    .IN_WIDTH(IN_WIDTH),
                    .ACC_WIDTH(ACC_WIDTH)
                ) u_pe (
                    .clk(clk),
                    .rst_n(rst_n),
                    .clr_acc(clr_acc),
                    .enable(mac_enable),
                    .act_in(act_elem),
                    .wgt_in(wgt_elem),
                    .acc_out(raw_accumulators[i][j])
                );

                post_processor #(
                    .ACC_WIDTH(ACC_WIDTH),
                    .OUT_WIDTH(OUT_WIDTH)
                ) u_post_proc (
                    .acc_in(raw_accumulators[i][j]),
                    .shift_amount(signed_shift),
                    .data_out(out_matrix_flat[(i*N + j)*OUT_WIDTH +: OUT_WIDTH])
                );

            end
        end
    endgenerate

endmodule