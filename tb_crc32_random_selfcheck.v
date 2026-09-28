// =============================================================================
// tb_crc32_random_selfcheck.v
//
// Randomized differential test. For each of NUM_ITERS iterations:
//   - picks a random message length (1..MAX_LEN bytes) and random content
//   - streams it into the DATA_WIDTH=8 DUT, with a random number of idle
//     "bubble" cycles (data_valid=0) inserted at random points
//   - computes the expected CRC with an *independently coded* software
//     model (crc32_sw_ref below), which uses the classic LSB-first
//     "reflected table-free" algorithm -- a different bit-ordering /
//     shift-direction than the DUT's MSB-first-with-REFIN-reflect
//     approach in crc32_byte(), so the two are unlikely to share a bug.
//   - compares
//
// It also periodically cross-checks the DATA_WIDTH=32 engine against the
// DATA_WIDTH=8 engine on the same random message (message length forced to
// a multiple of 4 for those iterations, per the limitation documented in
// tb_crc32_multibyte.v).
//
// Uses the module's default parameters (CRC-32 Ethernet/zlib: poly
// 0x04C11DB7, init 0xFFFFFFFF, xorout 0xFFFFFFFF, REFIN=REFOUT=1), since
// that is the variant crc32_sw_ref implements.
// =============================================================================
`timescale 1ns/1ps

module tb_crc32_random_selfcheck;

    parameter integer NUM_ITERS = 200;
    parameter integer MAX_LEN   = 64;

    reg clk = 0;
    reg rst_n;
    always #5 clk = ~clk;

    integer errors = 0;
    integer checks = 0;
    integer seed = 32'hC0FFEE01;

    // ---------------------------------------------------------------
    // Independent software reference model: standard reflected,
    // table-free, LSB-first-shifting CRC-32 (the classic zlib/PKZIP
    // algorithm). This is algorithmically distinct from the DUT's
    // MSB-first shift-with-byte-reflect implementation.
    //
    // NOTE: reads the module-scope 'msg' array directly rather than
    // taking it as a function argument -- plain Verilog (IEEE 1364)
    // function/task ports must be scalar/vector, not unpacked arrays,
    // so passing 'msg[]' as a parameter is a SystemVerilog-only
    // extension that not every toolchain accepts. Referencing the
    // module-scope memory keeps this file portable.
    // ---------------------------------------------------------------
    reg [7:0] msg [0:1023];

    function [31:0] crc32_sw_ref;
        input integer len;
        integer i, b;
        reg [31:0] c;
        begin
            c = 32'hFFFFFFFF;
            for (i = 0; i < len; i = i + 1) begin
                c = c ^ {24'b0, msg[i]};
                for (b = 0; b < 8; b = b + 1) begin
                    if (c[0])
                        c = (c >> 1) ^ 32'hEDB88320; // bit-reflected poly 0x04C11DB7
                    else
                        c = c >> 1;
                end
            end
            crc32_sw_ref = c ^ 32'hFFFFFFFF;
        end
    endfunction

    task check32;
        input [255:0] name;
        input [31:0]  got;
        input [31:0]  exp;
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("[FAIL] %0s : got=%08h expected=%08h", name, got, exp);
            end else begin
                // keep output short for large iteration counts
                if (errors == 0 && (checks % 25 == 0))
                    $display("[PASS] ... %0d checks so far, 0 failures", checks);
            end
        end
    endtask

    // ============================ DUT: 8-bit ===============================
    reg        d8_start, d8_done, d8_dvalid;
    reg [7:0]  d8_din;
    wire       d8_busy, d8_valid, d8_ready;
    wire [31:0] d8_out;

    crc32_engine #(.DATA_WIDTH(8)) dut8 (
        .clk(clk), .rst_n(rst_n), .start(d8_start), .done(d8_done),
        .busy(d8_busy), .crc_valid(d8_valid), .crc_out(d8_out),
        .data_valid(d8_dvalid), .data_in(d8_din), .ready(d8_ready)
    );

    // ============================ DUT: 32-bit ==============================
    reg        d32_start, d32_done, d32_dvalid;
    reg [31:0] d32_din;
    wire       d32_busy, d32_valid, d32_ready;
    wire [31:0] d32_out;

    crc32_engine #(.DATA_WIDTH(32)) dut32 (
        .clk(clk), .rst_n(rst_n), .start(d32_start), .done(d32_done),
        .busy(d32_busy), .crc_valid(d32_valid), .crc_out(d32_out),
        .data_valid(d32_dvalid), .data_in(d32_din), .ready(d32_ready)
    );

    integer len, k;
    integer iter;
    reg [31:0] rnd; // scratch: unsigned reg so %/masking behave as unsigned

    task run_dut8(input integer mlen, output [31:0] result);
    begin
        @(negedge clk); d8_start = 1;
        @(negedge clk); d8_start = 0;
        k = 0;
        while (k < mlen) begin
            @(negedge clk);
            // randomly insert a bubble ~25% of the time instead of a byte
            rnd = $random(seed);
            if ((rnd % 4) == 0) begin
                d8_dvalid = 0;
                d8_done   = 0;
            end else begin
                d8_din    = msg[k];
                d8_dvalid = 1;
                d8_done   = (k == mlen-1);
                k = k + 1;
            end
        end
        @(negedge clk); d8_dvalid = 0; d8_done = 0;
        @(posedge clk);
        result = d8_out;
    end
    endtask

    task run_dut32(input integer mlen, output [31:0] result);
        integer w;
    begin
        @(negedge clk); d32_start = 1;
        @(negedge clk); d32_start = 0;
        for (w = 0; w < mlen; w = w + 4) begin
            @(negedge clk);
            d32_din = {msg[w+3], msg[w+2], msg[w+1], msg[w]};
            d32_dvalid = 1;
            d32_done = (w == mlen-4);
        end
        @(negedge clk); d32_dvalid = 0; d32_done = 0;
        @(posedge clk);
        result = d32_out;
    end
    endtask

    reg [31:0] exp_crc, got8, got32;

    initial begin
        rst_n = 0;
        d8_start=0; d8_done=0; d8_dvalid=0; d8_din=0;
        d32_start=0; d32_done=0; d32_dvalid=0; d32_din=0;
        repeat (3) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        for (iter = 0; iter < NUM_ITERS; iter = iter + 1) begin
            // random length 1..MAX_LEN
            rnd = $random(seed);
            len = (rnd % MAX_LEN) + 1;
            for (k = 0; k < len; k = k + 1) begin
                rnd = $random(seed);
                msg[k] = rnd[7:0];
            end

            exp_crc = crc32_sw_ref(len);

            run_dut8(len, got8);
            check32("random DATA_WIDTH=8 vs sw reference model", got8, exp_crc);

            // Every 4th iteration, also force length to a multiple of 4
            // and cross-check the 32-bit engine against both the 8-bit
            // engine's result and the software reference.
            if ((iter % 4) == 3) begin
                len = len - (len % 4);
                if (len == 0) len = 4;
                run_dut8(len, got8);
                run_dut32(len, got32);
                exp_crc = crc32_sw_ref(len);
                check32("random DATA_WIDTH=32 vs sw reference model", got32, exp_crc);
                check32("random DATA_WIDTH=32 vs DATA_WIDTH=8 DUT",   got32, got8);
            end
        end

        $display("--------------------------------------------------");
        $display("tb_crc32_random_selfcheck: %0d checks, %0d failures (over %0d random messages)",
                  checks, errors, NUM_ITERS);
        if (errors == 0) $display("RESULT: ALL PASS");
        else              $display("RESULT: FAILED");
        $finish;
    end

    initial begin
        #2000000;
        $display("[FAIL] TIMEOUT - simulation did not finish");
        $finish;
    end

endmodule
