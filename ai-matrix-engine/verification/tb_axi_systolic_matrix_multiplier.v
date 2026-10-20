`timescale 1ns/1ps

module tb_axi_systolic_matrix_multiplier;

    // VCD Dump
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_axi_systolic_matrix_multiplier);
    end

    // Parameters
    parameter integer M          = 4;
    parameter integer N          = 4;
    parameter integer IN_WIDTH   = 8;
    parameter integer ACC_WIDTH  = 32;
    parameter integer OUT_WIDTH  = 16;
    parameter time CLK_PERIOD    = 10;

    // Signals
    reg clk;
    reg rst_n;

    reg signed [M*IN_WIDTH-1:0] s_axis_a_tdata;
    reg                         s_axis_a_tvalid;
    wire                        s_axis_a_tready;

    reg signed [N*IN_WIDTH-1:0] s_axis_b_tdata;
    reg                         s_axis_b_tvalid;
    wire                        s_axis_b_tready;

    reg [7:0]                   ctrl_shift_amount;
    reg                         ctrl_clr_acc;

    wire signed [M*N*OUT_WIDTH-1:0] m_axis_c_tdata;
    wire                            m_axis_c_tvalid;
    reg                             m_axis_c_tready;
    wire                            m_axis_c_tlast;

    integer test_case_count = 0;
    integer pass_count      = 0;
    integer fail_count      = 0;

    integer i, j, k;
    reg test_passed;

    parameter integer MAX_K = 64;
    reg signed [IN_WIDTH-1:0] A_tb [0:M-1][0:MAX_K-1];
    reg signed [IN_WIDTH-1:0] B_tb [0:MAX_K-1][0:N-1];

    // DUT Instantiation
    axi_systolic_matrix_multiplier #(
        .M(M),
        .N(N),
        .IN_WIDTH(IN_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .OUT_WIDTH(OUT_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_a_tdata(s_axis_a_tdata),
        .s_axis_a_tvalid(s_axis_a_tvalid),
        .s_axis_a_tready(s_axis_a_tready),
        .s_axis_b_tdata(s_axis_b_tdata),
        .s_axis_b_tvalid(s_axis_b_tvalid),
        .s_axis_b_tready(s_axis_b_tready),
        .ctrl_shift_amount(ctrl_shift_amount),
        .ctrl_clr_acc(ctrl_clr_acc),
        .m_axis_c_tdata(m_axis_c_tdata),
        .m_axis_c_tvalid(m_axis_c_tvalid),
        .m_axis_c_tready(m_axis_c_tready),
        .m_axis_c_tlast(m_axis_c_tlast)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    // Backpressure Driver
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axis_c_tready <= 1'b1;
        end else begin
            m_axis_c_tready <= (($random & 32'h7FFFFFFF) % 100) < 70;
        end
    end

    // Reference Model
    function signed [OUT_WIDTH-1:0] reference_post_proc;
        input signed [ACC_WIDTH-1:0] acc_val;
        input        [7:0]          shift;
        reg   signed [ACC_WIDTH-1:0] shifted_acc;
        
        integer max_pos, min_neg;
        begin
            max_pos = (1 << (OUT_WIDTH - 1)) - 1;
            min_neg = -(1 << (OUT_WIDTH - 1));

            shifted_acc = acc_val >>> $signed({1'b0, shift});
            
            if ($signed(shifted_acc) > max_pos)
                reference_post_proc = max_pos[OUT_WIDTH-1:0];
            else if ($signed(shifted_acc) < min_neg)
                reference_post_proc = min_neg[OUT_WIDTH-1:0];
            else
                reference_post_proc = shifted_acc[OUT_WIDTH-1:0];
        end
    endfunction

    function [31:0] get_positive_rand;
        input dummy;
        reg [31:0] raw_r;
        begin
            raw_r = $random;
            get_positive_rand = raw_r & 32'h7FFFFFFF;
        end
    endfunction

    function signed [7:0] get_rand_int8;
        input dummy;
        integer r;
        begin
            r = (get_positive_rand(1'b0) % 256) - 128;
            get_rand_int8 = r[7:0];
        end
    endfunction

    // Clean Driver & Scoreboard
    task run_axis_matrix_test;
        input [8*32-1:0] test_name;
        input integer    k_length;   
        input [7:0]      shift_val;
        
        reg signed [ACC_WIDTH-1:0] gold_acc [0:M-1][0:N-1];
        reg signed [OUT_WIDTH-1:0] gold_out [0:M-1][0:N-1];
        reg signed [OUT_WIDTH-1:0] rtl_out  [0:M-1][0:N-1];
        integer cur_k;
        
        begin
            test_passed = 1;
            test_case_count = test_case_count + 1;

            for (i = 0; i < M; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    gold_acc[i][j] = 0;
                    for (k = 0; k < k_length; k = k + 1) begin
                        gold_acc[i][j] = gold_acc[i][j] + ($signed(A_tb[i][k]) * $signed(B_tb[k][j]));
                    end
                    gold_out[i][j] = reference_post_proc(gold_acc[i][j], shift_val);
                end
            end

            ctrl_shift_amount <= shift_val;
            cur_k = 0;

            while (cur_k < k_length) begin
                for (i = 0; i < M; i = i + 1) 
                    s_axis_a_tdata[i*IN_WIDTH +: IN_WIDTH] = A_tb[i][cur_k];
                for (j = 0; j < N; j = j + 1) 
                    s_axis_b_tdata[j*IN_WIDTH +: IN_WIDTH] = B_tb[cur_k][j];

                s_axis_a_tvalid = 1'b1;
                s_axis_b_tvalid = 1'b1;
                ctrl_clr_acc    = (cur_k == 0) ? 1'b1 : 1'b0;

                @(posedge clk);

                if (s_axis_a_tvalid && s_axis_a_tready && s_axis_b_tvalid && s_axis_b_tready) begin
                    cur_k = cur_k + 1;
                end
            end

            @(posedge clk);
            s_axis_a_tvalid <= 1'b0;
            s_axis_b_tvalid <= 1'b0;
            ctrl_clr_acc    <= 1'b0;
            s_axis_a_tdata  <= 0;
            s_axis_b_tdata  <= 0;

            while (!m_axis_c_tvalid || !m_axis_c_tready) begin
                @(posedge clk);
            end

            for (i = 0; i < M; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    rtl_out[i][j] = $signed(m_axis_c_tdata[(i*N + j)*OUT_WIDTH +: OUT_WIDTH]);
                    if (rtl_out[i][j] !== gold_out[i][j]) begin
                        $display("[MISMATCH] [%0d,%0d] | Gold Acc: %0d | Gold Quantized: %0d | RTL Got: %0d",
                                 i, j, gold_acc[i][j], gold_out[i][j], rtl_out[i][j]);
                        test_passed = 0;
                    end
                end
            end

            if (test_passed) begin
                $display("[PASS] Test %0d: %s", test_case_count, test_name);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_case_count, test_name);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        clk               = 0;
        rst_n             = 0;
        s_axis_a_tvalid   = 0;
        s_axis_b_tvalid   = 0;
        s_axis_a_tdata    = 0;
        s_axis_b_tdata    = 0;
        ctrl_clr_acc      = 0;
        ctrl_shift_amount = 0;

        #(CLK_PERIOD * 4);
        rst_n = 1;
        #(CLK_PERIOD * 4);

        // Test 1: K = 4
        for (i = 0; i < M; i = i + 1)
            for (k = 0; k < 4; k = k + 1)
                A_tb[i][k] = get_rand_int8(1'b0);

        for (k = 0; k < 4; k = k + 1)
            for (j = 0; j < N; j = j + 1)
                B_tb[k][j] = get_rand_int8(1'b0);

        run_axis_matrix_test("Short Stream Packet (K=4)", 4, 8'd2);

        // Test 2: K = 16
        for (i = 0; i < M; i = i + 1)
            for (k = 0; k < 16; k = k + 1)
                A_tb[i][k] = get_rand_int8(1'b0);

        for (k = 0; k < 16; k = k + 1)
            for (j = 0; j < N; j = j + 1)
                B_tb[k][j] = get_rand_int8(1'b0);

        run_axis_matrix_test("Medium Stream Packet (K=16)", 16, 8'd4);

        $display("\n=========================================================");
        $display("   FINAL STATUS: %0d / %0d TESTS PASSED", pass_count, test_case_count);
        $display("=========================================================");

        $finish;
    end

endmodule