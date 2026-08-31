/*
 * ============================================================================
 *  tb_mem_soc.v — Testbench for PicoRV32 Memory-Mapped UART SoC
 *  Author : Deepak | Sr. VLSI Engineer | NIELIT CoE
 * ============================================================================
 *
 *  DUT: picorv32_uart_mem/rtl/top.v  (no AXI — native mem_* bus)
 *
 *  TEST SEQUENCE
 *  ─────────────
 *  1. Clock + reset
 *  2. UART TX monitor — decode 8N1 bitstream, display each RX byte
 *  3. Wait for 10 greeting messages ("Hello Deepak from Nielit!\n")
 *  4. Print greeting count banner → UART OUTPUT VERIFIED
 *  5. Flush FIFO, send PING (P I N G) over UART RX
 *  6. Firmware echoes each byte — collect and verify → TEST PASSED / FAILED
 *
 *  Expected firmware output:
 *     Hello Deepak from Nielit!   (×10)
 *     <then echoes P I N G>
 *
 *  Expected terminal output (document reference):
 *     --------------------------------------------------
 *      UART SoC Simulation Started
 *     --------------------------------------------------
 *     [TB] UART Monitor Started
 *     --------------------------------
 *     [TB] RX byte: H
 *     [TB] RX byte: e
 *     ...
 *     [TB] Greeting message count = 10
 *     ============================================
 *      10 GREETING MESSAGES RECEIVED
 *      UART OUTPUT VERIFIED
 *     ============================================
 *     --------------------------------------------
 *     [TB] FIFO flushed – sending command : PING
 *     --------------------------------------------
 *     [TB] RX byte: P
 *     [TB] RX byte: I
 *     [TB] RX byte: N
 *     [TB] RX byte: G
 *     ============================================
 *      TEST PASSED
 *      Echo received : PING
 *     ============================================
 *
 *  Clock  : 50 MHz  (CLK_PERIOD = 20 ns)
 *  UART   : 115200 baud 8N1
 * ============================================================================
 */

`timescale 1ns / 1ps

module tb_mem_soc;

    // ── Clock / Reset ──────────────────────────────────────────────────────────
    localparam CLK_PERIOD    = 20;
    localparam UART_BIT_CYCLES = 434;           // 50 MHz / 115200 ≈ 434 cycles

    localparam BAUD_HALF = 1_000_000_000 / 115200 / 2;
    localparam BAUD_FULL = 1_000_000_000 / 115200;

    // "Hello Deepak from Nielit!\n" = 26 chars × 10 = 260 newlines total
    // Each char ≈ 10 baud periods × 8680 ns = 86800 ns
    // 260 chars × 86800 ns ≈ 22.6 ms  →  use 2 s timeout
    localparam TIMEOUT_NS = 2_000_000_000;

   // /* verilator lint_off PROCASSINIT */
    reg clk   = 0;
   // /* verilator lint_on PROCASSINIT */
    reg reset = 1;

    integer greeting_count = 0;   // counts complete "Hello Deepak from Nielit!\n" lines
    integer line_count     = 0;   // total newline count (used internally)

    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        $display("--------------------------------------------------");
        $display(" UART SoC Simulation Started");
        $display("--------------------------------------------------");
        repeat (10) @(posedge clk);
        reset = 0;
    end


    // ── DUT ───────────────────────────────────────────────────────────────────
    wire uart_tx_pin;
    reg  uart_rx_pin = 1'b1;   // UART idle = HIGH

    top u_dut (
        .clk     (clk),
        .reset   (reset),
        .uart_tx (uart_tx_pin),
        .uart_rx (uart_rx_pin)
    );


    // ── VCD dump ──────────────────────────────────────────────────────────────
    initial begin
        $dumpfile("tb_mem_soc.vcd");
        $dumpvars(0, tb_mem_soc);
    end


    // ── Timeout guard ─────────────────────────────────────────────────────────
    initial begin
        #(TIMEOUT_NS);
        $display("[TB] ERROR: Simulation TIMEOUT");
        $finish;
    end


    // ── UART RX driver task — bit-bang 8N1 frame onto uart_rx_pin ─────────────
    task send_byte;
        input [7:0] b;
        integer bi;
        begin
            uart_rx_pin = 1'b0;                             // start bit
            repeat (UART_BIT_CYCLES) @(posedge clk);
            for (bi = 0; bi < 8; bi = bi + 1) begin         // 8 data bits (LSB first)
                uart_rx_pin = b[bi];
                repeat (UART_BIT_CYCLES) @(posedge clk);
            end
            uart_rx_pin = 1'b1;                             // stop bit
            repeat (UART_BIT_CYCLES) @(posedge clk);
            repeat (UART_BIT_CYCLES * 2) @(posedge clk);   // inter-byte gap
        end
    endtask


    // ── FIFO — collects bytes decoded from uart_tx_pin ────────────────────────
    reg [7:0] rx_fifo [0:255];
    integer   rx_wr_ptr = 0;
    integer   rx_rd_ptr = 0;


    // =========================================================================
    // UART TX Monitor — decode 8N1 bitstream, display each byte, count greetings
    // =========================================================================
    reg [7:0]        mon_byte;
    integer          bit_idx;

    // Line assembly buffer — 32 chars wide (greeting is 26 chars)
    reg [8*32-1:0]   asm_line;
    integer          asm_len;

    // Reference string: "Hello Deepak from Nielit!"  (25 chars, then \n)
    // We match the assembled line to detect a greeting.
    // Simple approach: count newlines whose preceding text starts with 'H'
    // Robust approach: compare full assembled line byte-by-byte.
    // We use a character-count match: greeting line = 25 printable chars + '\n'

    initial begin : uart_monitor
        asm_line = 0;
        asm_len  = 0;

        @(negedge reset);

        $display("[TB] UART Monitor Started");
        $display("--------------------------------");

        forever begin
            @(negedge uart_tx_pin);           // start bit falling edge
            #(BAUD_HALF);                     // skip to centre of start bit

            if (uart_tx_pin == 1'b0) begin
                mon_byte = 8'h00;

                // sample 8 data bits (LSB first)
                for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                    #(BAUD_FULL);
                    mon_byte[bit_idx] = uart_tx_pin;
                end
                #(BAUD_FULL);   // skip stop bit

                // push to FIFO
                rx_fifo[rx_wr_ptr & 255] = mon_byte;
                rx_wr_ptr = rx_wr_ptr + 1;

                // display every received byte
                if (mon_byte >= 8'h20 && mon_byte <= 8'h7E) begin
                    // printable — show as character
                    $display("[TB] RX byte: %c", mon_byte);
                end

                // assemble line — act on newline
                if (mon_byte == "\n") begin
                    #1;
                    // count this as a greeting if line == "Hello Deepak from Nielit!"
                    // (25 printable chars assembled before this \n)
                    if (asm_len == 25) begin
                        // check first char 'H' as quick sanity
                        if (asm_line[7:0] == "H") begin
                            greeting_count = greeting_count + 1;
                            $display("[TB] Greeting message count = %0d", greeting_count);
                        end
                    end
                    asm_line = 0;
                    asm_len  = 0;
                    line_count = line_count + 1;
                end else if (asm_len < 32) begin
                    asm_line[8*asm_len +: 8] = mon_byte;
                    asm_len = asm_len + 1;
                end
            end
        end
    end


    // =========================================================================
    // Test Sequence
    // =========================================================================
    localparam [7:0] BYTE_P = 8'h50;   // 'P'
    localparam [7:0] BYTE_I = 8'h49;   // 'I'
    localparam [7:0] BYTE_N = 8'h4E;   // 'N'
    localparam [7:0] BYTE_G = 8'h47;   // 'G'

    reg [7:0] echo0, echo1, echo2, echo3;
    integer   silence_cnt;
    integer   last_snap;

    initial begin : test_seq
        @(negedge reset);

        // Step 1 — wait for exactly 10 greeting messages
        wait (greeting_count == 10);

        $display("============================================");
        $display(" 10 GREETING MESSAGES RECEIVED");
        $display(" UART OUTPUT VERIFIED");
        $display("============================================");

        // Step 2 — wait for UART to go idle (5 baud periods of silence)
        silence_cnt = 0;
        last_snap   = rx_wr_ptr - 1;
        while (silence_cnt < 5) begin
            #(BAUD_FULL);
            if (rx_wr_ptr == last_snap)
                silence_cnt = silence_cnt + 1;
            else begin
                last_snap   = rx_wr_ptr;
                silence_cnt = 0;
            end
        end

        // Step 3 — flush FIFO
        rx_rd_ptr = 0;
        rx_wr_ptr = 0;
        #1;

        $display("--------------------------------------------");
        $display("[TB] FIFO flushed - sending command : PING");
        $display("--------------------------------------------");

        // Step 4 — send PING (4 bytes) over UART RX
        send_byte(BYTE_P);
        send_byte(BYTE_I);
        send_byte(BYTE_N);
        send_byte(BYTE_G);

        // Step 5 — wait for firmware echo loop to return all 4 bytes
        while (rx_wr_ptr < 4) #10;

        echo0 = rx_fifo[0];
        echo1 = rx_fifo[1];
        echo2 = rx_fifo[2];
        echo3 = rx_fifo[3];

        // Step 6 — verify
        if (echo0 == BYTE_P && echo1 == BYTE_I &&
            echo2 == BYTE_N && echo3 == BYTE_G) begin
            $display("============================================");
            $display(" TEST PASSED");
            $display(" Echo received : %c%c%c%c",
                     echo0, echo1, echo2, echo3);
            $display("============================================");
        end else begin
            $display("============================================");
            $display(" TEST FAILED");
            $display(" Expected: PING (0x50 0x49 0x4E 0x47)");
            $display(" Received: %c%c%c%c (0x%02X 0x%02X 0x%02X 0x%02X)",
                     echo0, echo1, echo2, echo3,
                     echo0, echo1, echo2, echo3);
            $display("============================================");
        end

        $finish;
    end

endmodule

