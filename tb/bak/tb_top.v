/*
------------------------------------------------------------------------------
 Author       : Deepak
 Designation  : Sr. VLSI Engineer
 Organization : NIELIT CoE
------------------------------------------------------------------------------

MODULE OVERVIEW
---------------
This file is a **testbench** used to simulate and verify a small RISC-V SoC.

A testbench is **not hardware**. It is a simulation program that:
• drives inputs to the design
• observes outputs from the design
• checks if the design behaves correctly

In this project the SoC contains a **PicoRV32 CPU connected to a UART peripheral**.
The firmware running on the CPU prints messages through UART.

This testbench performs three main jobs:

1. Generate clock and reset for the SoC
2. Monitor the UART output from the SoC
3. Send a command ("PING") to the SoC and verify the response

If the SoC correctly echoes back "PING", the testbench prints **TEST PASSED**.

You can imagine the system like this:

        +----------------------+
        |   PicoRV32 SoC       |
        |                      |
        |  Firmware prints    |
        |  messages via UART  |
        +----------+-----------+
                   |
               uart_tx
                   |
             Testbench Monitor
                   |
                 FIFO
                   |
             Test Sequence
                   |
                uart_rx

The testbench acts like a **virtual computer terminal** talking to the SoC.
*/

// =============================================================================
// tb_top.v – Testbench for PicoRV32 AXI-Lite SoC (UART TX + RX)
// =============================================================================

`timescale 1ns / 1ps
// Simulation time unit = 1ns
// Simulation precision = 1ps

module tb_top;

    // -------------------------------------------------------------------------
    // Clock / Reset
    // -------------------------------------------------------------------------
    // These parameters define timing for the simulation

    localparam CLK_PERIOD    = 20;       // 20 ns clock period → 50 MHz clock

    // UART running at 115200 baud
    // Number of clock cycles required to transmit one UART bit
    localparam UART_BIT_CYCLES = 434;    

    // These delays are used by the UART monitor
    // They represent half and full UART bit times in nanoseconds

    localparam BAUD_HALF = 1_000_000_000 / 115200 / 2;  
    localparam BAUD_FULL = 1_000_000_000 / 115200;      

    // Clock and reset signals for the DUT
    reg clk   = 0;
    reg reset = 1;

    // Counts how many greeting lines firmware printed
    integer hello_count = 0;

    // Clock generator
    // This toggles the clock every half period
    always #(CLK_PERIOD/2) clk = ~clk;

    // Reset sequence
    // Hold reset for a few clock cycles before starting simulation
    initial begin
        $display("--------------------------------------------------");
        $display(" UART SoC Simulation Started");
        $display("--------------------------------------------------");

        repeat (10) @(posedge clk); // wait 10 clock cycles
        reset = 0;                  // release reset
    end


    // -------------------------------------------------------------------------
    // DUT (Device Under Test)
    // -------------------------------------------------------------------------
    // This instantiates the actual hardware design being tested

    wire uart_tx_pin;       // UART transmit from the SoC
    reg  uart_rx_pin = 1'b1;// UART receive input to the SoC (idle = 1)

    top u_dut (
        .clk(clk),
        .reset(reset),
        .uart_tx(uart_tx_pin),
        .uart_rx(uart_rx_pin)
    );


    // -------------------------------------------------------------------------
    // Waveform dump
    // -------------------------------------------------------------------------
    // Generates a VCD file so signals can be viewed in GTKWave

    initial begin
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);
    end


    // -------------------------------------------------------------------------
    // Timeout protection
    // -------------------------------------------------------------------------
    // If simulation runs too long, something is probably wrong.
    // This stops the simulation after 500 ms of simulated time.

    initial begin
        #500_000_000;
        $display("\n[TB] ERROR: Simulation TIMEOUT");
        $finish;
    end


    // -------------------------------------------------------------------------
    // UART RX Driver
    // -------------------------------------------------------------------------
    // This task sends one byte to the DUT through the UART RX pin.
    //
    // UART frame format:
    //
    //    START | 8 DATA BITS | STOP
    //       0        LSB→MSB     1
    //
    // Each bit lasts UART_BIT_CYCLES clock cycles.
    //
    // Example frame:
    //    0 1 0 1 0 0 0 1 0 1
    //
    // The extra delay after the stop bit gives the firmware time
    // to process the received character.

    task send_uart_byte;
        input [7:0] byte_val;
        integer i;
        begin
            // Start bit (UART start = 0)
            uart_rx_pin = 1'b0;
            repeat(UART_BIT_CYCLES) @(posedge clk);

            // Send 8 data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx_pin = byte_val[i];
                repeat(UART_BIT_CYCLES) @(posedge clk);
            end

            // Stop bit (UART idle = 1)
            uart_rx_pin = 1'b1;
            repeat(UART_BIT_CYCLES) @(posedge clk);

            // Extra delay so firmware can read UART
            repeat(UART_BIT_CYCLES * 3) @(posedge clk);
        end
    endtask


    // -------------------------------------------------------------------------
    // RX FIFO (Monitor → Test Sequence)
    // -------------------------------------------------------------------------
    // This small FIFO stores characters captured from UART TX.

    reg [7:0] rx_fifo [0:63];

    integer rx_wr_ptr = 0; // write pointer
    integer rx_rd_ptr = 0; // read pointer

    // Task to read a byte from the FIFO
    task fifo_get_byte;
        output [7:0] data;
        begin
            // Wait until new data is available
            while (rx_rd_ptr == rx_wr_ptr)
                #10;

            data = rx_fifo[rx_rd_ptr & 63];
            rx_rd_ptr = rx_rd_ptr + 1;
        end
    endtask


    // -------------------------------------------------------------------------
    // UART TX Monitor
    // -------------------------------------------------------------------------
    // This logic watches the UART transmit line from the DUT.
    //
    // When the DUT sends serial data, this monitor reconstructs
    // the transmitted byte and stores it in the FIFO.

    reg [7:0] mon_byte;
    integer   bit_i;

    initial begin

        @(negedge reset);

        $display("\n[TB] UART Monitor Started");
        $display("--------------------------------------------");

        forever begin

            // Detect start bit
            @(negedge uart_tx_pin);

            // Move to center of first bit
            #(BAUD_HALF);

            // Confirm start bit
            if (uart_tx_pin == 0) begin

                mon_byte = 0;

                // Capture 8 data bits
                for (bit_i = 0; bit_i < 8; bit_i = bit_i + 1) begin
                    #(BAUD_FULL);
                    mon_byte[bit_i] = uart_tx_pin;
                end

                // Skip stop bit
                #(BAUD_FULL);

                // Print received character to console
                $write("%c", mon_byte);

                // Store byte in FIFO
                rx_fifo[rx_wr_ptr & 63] = mon_byte;
                rx_wr_ptr = rx_wr_ptr + 1;

                // Detect newline characters from firmware
                if (mon_byte == "\n") begin
                    hello_count = hello_count + 1;

                    $display("\n[TB] Greeting message count = %0d", hello_count);

                    if (hello_count == 10) begin
                        $display("\n============================================");
                        $display(" 10 GREETING MESSAGES RECEIVED");
                        $display(" UART OUTPUT VERIFIED");
                        $display("============================================\n");
                    end
                end
            end
        end
    end


    // -------------------------------------------------------------------------
    // Test Sequence
    // -------------------------------------------------------------------------
    // This section performs the actual verification test.

    localparam [7:0] PING_P = "P";
    localparam [7:0] PING_I = "I";
    localparam [7:0] PING_N = "N";
    localparam [7:0] PING_G = "G";

    reg [7:0] echo0, echo1, echo2, echo3;
    reg [7:0] temp;

    integer last_wr_snap;
    integer silence_cnt;

    initial begin

        @(negedge reset);

        // Wait until firmware prints 10 greeting lines
        wait (hello_count == 10);

        $display("\n--------------------------------------------");
        $display("[TB] Greeting phase finished");
        $display("--------------------------------------------");

        // Wait until UART becomes idle
        silence_cnt  = 0;
        last_wr_snap = rx_wr_ptr - 1;

        while (silence_cnt < 5) begin
            #(BAUD_FULL);

            if (rx_wr_ptr == last_wr_snap)
                silence_cnt = silence_cnt + 1;
            else begin
                last_wr_snap = rx_wr_ptr;
                silence_cnt  = 0;
            end
        end

        // Clear FIFO
        rx_rd_ptr = 0;
        rx_wr_ptr = 0;

        #1;

        $display("\n--------------------------------------------");
        $display("[TB] FIFO flushed – sending command : PING");
        $display("--------------------------------------------");

        // Send command PING
        send_uart_byte(PING_P);
        send_uart_byte(PING_I);
        send_uart_byte(PING_N);
        send_uart_byte(PING_G);

        $display("[TB] Waiting for echo response ...");

        // Wait for first P
        temp = 0;
        while (temp != PING_P)
            fifo_get_byte(temp);

        echo0 = temp;
        fifo_get_byte(echo1);
        fifo_get_byte(echo2);
        fifo_get_byte(echo3);

        // Verify result
        if (echo0 == PING_P &&
            echo1 == PING_I &&
            echo2 == PING_N &&
            echo3 == PING_G) begin

            $display("\n============================================");
            $display(" TEST PASSED");
            $display(" Echo received : %c%c%c%c", echo0, echo1, echo2, echo3);
            $display("============================================\n");

        end else begin

            $display("\n============================================");
            $display(" TEST FAILED");
            $display(" Expected : PING");
            $display(" Received : %c%c%c%c", echo0, echo1, echo2, echo3);
            $display("============================================\n");

        end

        $finish;

    end

endmodule