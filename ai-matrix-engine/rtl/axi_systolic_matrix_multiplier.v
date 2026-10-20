//=============================================================================
// Parameterized AXI4-Stream Wrapper for Systolic Matrix Multiplier
//=============================================================================
module axi_systolic_matrix_multiplier #(
    parameter integer M          = 4,
    parameter integer N          = 4,
    parameter integer IN_WIDTH   = 8,
    parameter integer ACC_WIDTH  = 32,
    parameter integer OUT_WIDTH  = 16
)(
    input  wire                         clk,
    input  wire                         rst_n,

    // Slave AXI4-Stream Interface A (Activations)
    input  wire signed [M*IN_WIDTH-1:0] s_axis_a_tdata,
    input  wire                         s_axis_a_tvalid,
    output wire                         s_axis_a_tready,

    // Slave AXI4-Stream Interface B (Weights)
    input  wire signed [N*IN_WIDTH-1:0] s_axis_b_tdata,
    input  wire                         s_axis_b_tvalid,
    output wire                         s_axis_b_tready,

    // Sideband Controls
    input  wire [7:0]                   ctrl_shift_amount,
    input  wire                         ctrl_clr_acc,

    // Master AXI4-Stream Interface C
    output wire signed [M*N*OUT_WIDTH-1:0] m_axis_c_tdata,
    output reg                          m_axis_c_tvalid,
    input  wire                         m_axis_c_tready,
    output reg                          m_axis_c_tlast
);

    wire join_valid;
    wire mac_enable;

    // Both slaves must present valid data together
    assign join_valid      = s_axis_a_tvalid && s_axis_b_tvalid;
    
    // Slaves accept data when master output is unblocked
    assign s_axis_a_tready = join_valid && (m_axis_c_tready || !m_axis_c_tvalid);
    assign s_axis_b_tready = join_valid && (m_axis_c_tready || !m_axis_c_tvalid);

    // Core MAC operation triggers ONLY when handshake succeeds
    assign mac_enable      = join_valid && s_axis_a_tready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axis_c_tvalid <= 1'b0;
            m_axis_c_tlast  <= 1'b0;
        end else begin
            if (mac_enable) begin
                m_axis_c_tvalid <= 1'b1;
            end else if (m_axis_c_tready) begin
                m_axis_c_tvalid <= 1'b0;
            end
        end
    end

    systolic_matrix_multiplier #(
        .M(M),
        .N(N),
        .IN_WIDTH(IN_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .OUT_WIDTH(OUT_WIDTH)
    ) u_core_engine (
        .clk(clk),
        .rst_n(rst_n),
        .clr_acc(ctrl_clr_acc),
        .mac_enable(mac_enable),
        .shift_amount(ctrl_shift_amount),
        .act_matrix_flat(s_axis_a_tdata),
        .wgt_matrix_flat(s_axis_b_tdata),
        .out_matrix_flat(m_axis_c_tdata)
    );

endmodule