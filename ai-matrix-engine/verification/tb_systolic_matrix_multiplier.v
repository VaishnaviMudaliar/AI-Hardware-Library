`timescale 1ns/1ps

module tb_systolic_matrix_multiplier;

    parameter integer M          = 4;
    parameter integer N          = 4;
    parameter integer K_DIM      = 8;
    parameter integer IN_WIDTH   = 8;
    parameter integer ACC_WIDTH  = 32;
    parameter integer OUT_WIDTH  = 8;

    parameter time CLK_PERIOD    = 10;

    reg clk;
    reg rst_n;
    reg clr_acc;
    reg mac_enable;
    reg [7:0] shift_amount;

    reg  signed [M*IN_WIDTH-1:0]    act_matrix_flat;
    reg  signed [N*IN_WIDTH-1:0]    wgt_matrix_flat;
    wire signed [M*N*OUT_WIDTH-1:0] out_matrix_flat;

    // Local 2D array buffers inside Testbench
    reg signed [IN_WIDTH-1:0] A_tb [0:M-1][0:K_DIM-1];
    reg signed [IN_WIDTH-1:0] B_tb [0:K_DIM-1][0:N-1];

    integer test_case_count = 0;
    integer pass_count      = 0;
    integer fail_count      = 0;

    integer i, j, k, tc;
    reg test_passed;

    // Module Instantiation
    systolic_matrix_multiplier #(
        .M(M),
        .N(N),
        .IN_WIDTH(IN_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .OUT_WIDTH(OUT_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .clr_acc(clr_acc),
        .mac_enable(mac_enable),
        .shift_amount(shift_amount),
        .act_matrix_flat(act_matrix_flat),
        .wgt_matrix_flat(wgt_matrix_flat),
        .out_matrix_flat(out_matrix_flat)
    );

    // Clock Generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Reference Post-Processing Function
    function signed [OUT_WIDTH-1:0] reference_post_proc;
        input signed [ACC_WIDTH-1:0] acc_val;
        input        [7:0]          shift;
        reg   signed [ACC_WIDTH-1:0] shifted_acc;
        begin
            shifted_acc = acc_val >>> shift;
            if (shifted_acc > 32'sd127)
                reference_post_proc = 8'sd127;
            else if (shifted_acc < -32'sd128)
                reference_post_proc = -8'sd128;
            else
                reference_post_proc = shifted_acc[OUT_WIDTH-1:0];
        end
    endfunction

    // Test Execution Task
    task run_matrix_test;
        input [8*32-1:0] test_name; // 32-character string buffer
        input [7:0]      shift_val;
        
        reg signed [ACC_WIDTH-1:0] gold_acc [0:M-1][0:N-1];
        reg signed [OUT_WIDTH-1:0] gold_out [0:M-1][0:N-1];
        reg signed [OUT_WIDTH-1:0] rtl_out  [0:M-1][0:N-1];
        begin
            test_passed = 1;
            test_case_count = test_case_count + 1;

            $display("---------------------------------------------------------");
            $display("[TEST %0d] Starting: %s (Shift = %0d)", test_case_count, test_name, shift_val);
            $display("---------------------------------------------------------");

            // 1. Calculate Golden Reference Matrix
            for (i = 0; i < M; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    gold_acc[i][j] = 0;
                    for (k = 0; k < K_DIM; k = k + 1) begin
                        gold_acc[i][j] = gold_acc[i][j] + ($signed(A_tb[i][k]) * $signed(B_tb[k][j]));
                    end
                    gold_out[i][j] = reference_post_proc(gold_acc[i][j], shift_val);
                end
            end

            // 2. Drive Inputs to RTL
            shift_amount <= shift_val;
            @(posedge clk);
            
            clr_acc    <= 1'b1;
            mac_enable <= 1'b1;

            for (k = 0; k < K_DIM; k = k + 1) begin
                for (i = 0; i < M; i = i + 1) 
                    act_matrix_flat[i*IN_WIDTH +: IN_WIDTH] <= A_tb[i][k];
                for (j = 0; j < N; j = j + 1) 
                    wgt_matrix_flat[j*IN_WIDTH +: IN_WIDTH] <= B_tb[k][j];
                
                @(posedge clk);
                clr_acc <= 1'b0;
            end

            mac_enable      <= 1'b0;
            act_matrix_flat <= 0;
            wgt_matrix_flat <= 0;

            @(posedge clk);

            // 3. Extract Flat Outputs
            for (i = 0; i < M; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    rtl_out[i][j] = out_matrix_flat[(i*N + j)*OUT_WIDTH +: OUT_WIDTH];
                end
            end

            // 4. Compare Results
            for (i = 0; i < M; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    if (rtl_out[i][j] !== gold_out[i][j]) begin
                        $display("ERROR: [MISMATCH] Row %0d, Col %0d | Expected: %d (Acc: %d), Got: %d",
                                 i, j, gold_out[i][j], gold_acc[i][j], rtl_out[i][j]);
                        test_passed = 0;
                    end
                end
            end

            if (test_passed) begin
                $display("[SUCCESS] %s PASSED!", test_name);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %s FAILED!", test_name);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Helper function for signed random number generation in Verilog-2001
    function signed [7:0] get_rand_int8;
        input dummy; // Dummy input to satisfy Verilog-2001 function syntax
        integer r;
        begin
            r = $random % 128;
            get_rand_int8 = r[7:0];
        end
    endfunction

    initial begin
        clk             = 0;
        rst_n           = 0;
        clr_acc         = 0;
        mac_enable      = 0;
        shift_amount    = 0;
        act_matrix_flat = 0;
        wgt_matrix_flat = 0;

        #(CLK_PERIOD * 2);
        rst_n = 1;
        #(CLK_PERIOD * 2);

        // Test 1: Identity Matrix Test
        for (i = 0; i < M; i = i + 1)
            for (k = 0; k < K_DIM; k = k + 1)
                A_tb[i][k] = (i + 1) * 10;

        for (k = 0; k < K_DIM; k = k + 1)
            for (j = 0; j < N; j = j + 1)
                B_tb[k][j] = (k == j) ? 8'sd1 : 8'sd0;

        run_matrix_test("Identity Matrix Test", 8'd0);

        // Test 2: Extreme Values (Saturation Test)
        for (i = 0; i < M; i = i + 1)
            for (k = 0; k < K_DIM; k = k + 1)
                A_tb[i][k] = 8'sd127;

        for (k = 0; k < K_DIM; k = k + 1)
            for (j = 0; j < N; j = j + 1)
                B_tb[k][j] = 8'sd127;

        run_matrix_test("Saturating Overflow Test", 8'd0);

        // Test 3-10: Randomized Matrix Tests
        for (tc = 0; tc < 8; tc = tc + 1) begin
            for (i = 0; i < M; i = i + 1)
                for (k = 0; k < K_DIM; k = k + 1)
                    A_tb[i][k] = get_rand_int8(1'b0);

            for (k = 0; k < K_DIM; k = k + 1)
                for (j = 0; j < N; j = j + 1)
                    B_tb[k][j] = get_rand_int8(1'b0);

            run_matrix_test("Randomized Matrix Test", ($random % 10));
        end

        // Summary
        $display("\n=========================================================");
        $display("               TESTBENCH EXECUTION SUMMARY               ");
        $display("=========================================================");
        $display(" Total Tests Run : %0d", test_case_count);
        $display(" Total Passed    : %0d", pass_count);
        $display(" Total Failed    : %0d", fail_count);
        $display("=========================================================");

        if (fail_count == 0)
            $display(">>> ALL TESTS PASSED SUCCESSFULLY! <<<");
        else
            $display(">>> TESTBENCH FAILED WITH MISMATCHES <<<");

        $finish;
    end

endmodule