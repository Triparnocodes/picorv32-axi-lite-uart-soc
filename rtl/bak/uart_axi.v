/*
------------------------------------------------------------------------------
 Author       : Deepak
 Designation  : Sr. VLSI Engineer
 Organization : NIELIT CoE
------------------------------------------------------------------------------

MODULE OVERVIEW
---------------
UART peripheral connected to an AXI-Lite bus (full-duplex TX+RX).

ASIC-clean version:
  - Removed all inline reg initializers (= value)
  - Fixed TX write backpressure: CPU write is not accepted while buf_valid=1
    (prevents silent byte drop that causes CPU B-channel deadlock)
  - AXI write channel now properly holds awready/wready low when buffer full
*/

`timescale 1ns / 1ps

module uart_axi #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115_200
)(
    input         clk,
    input         reset,

    // AXI-Lite Write Address Channel
    input  [31:0] s_axi_awaddr,
    input         s_axi_awvalid,
    output        s_axi_awready,

    // AXI-Lite Write Data Channel
    input  [31:0] s_axi_wdata,
    input  [ 3:0] s_axi_wstrb,
    input         s_axi_wvalid,
    output        s_axi_wready,

    // AXI-Lite Write Response Channel
    output [ 1:0] s_axi_bresp,
    output        s_axi_bvalid,
    input         s_axi_bready,

    // AXI-Lite Read Address Channel
    input  [31:0] s_axi_araddr,
    input         s_axi_arvalid,
    output        s_axi_arready,

    // AXI-Lite Read Data Channel
    output [31:0] s_axi_rdata,
    output [ 1:0] s_axi_rresp,
    output        s_axi_rvalid,
    input         s_axi_rready,

    // Serial UART Pins
    output        uart_tx,
    input         uart_rx
);

    // =========================================================================
    // UART TRANSMITTER
    // =========================================================================
    reg  [7:0] tx_data;
    reg        tx_valid;
    wire       tx_ready;

    uart_tx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_tx (
        .clk   (clk),
        .reset (reset),
        .data  (tx_data),
        .valid (tx_valid),
        .ready (tx_ready),
        .tx    (uart_tx)
    );


    // =========================================================================
    // UART RECEIVER
    // =========================================================================
    wire [7:0] rx_data_raw;
    wire       rx_data_valid_pulse;

    uart_rx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_rx (
        .clk        (clk),
        .reset      (reset),
        .rx         (uart_rx),
        .data_out   (rx_data_raw),
        .data_valid (rx_data_valid_pulse)
    );


    // =========================================================================
    // TX BUFFER (1-element queue)
    // =========================================================================
    // Decouples AXI write timing from UART bit-serial timing.
    // All regs are reset-driven (no inline initializers).
    // =========================================================================
    reg [7:0] buf_data;
    reg       buf_valid;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tx_valid  <= 1'b0;
            tx_data   <= 8'h00;
            buf_valid <= 1'b0;
            buf_data  <= 8'h00;
        end else begin
            tx_valid <= 1'b0;  // default pulse-low

            if (tx_ready && buf_valid) begin
                tx_data   <= buf_data;
                tx_valid  <= 1'b1;
                buf_valid <= 1'b0;
            end
        end
    end


    // =========================================================================
    // RX BUFFER (1-element)
    // =========================================================================
    reg [7:0] rx_buf_data;
    reg       rx_buf_valid;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_buf_data  <= 8'h00;
            rx_buf_valid <= 1'b0;
        end else begin
            if (rx_data_valid_pulse) begin
                rx_buf_data  <= rx_data_raw;
                rx_buf_valid <= 1'b1;
            end

            // Clear RX_VALID when CPU reads the DATA register
            if (r_vld && s_axi_rready && !r_is_stat)
                rx_buf_valid <= 1'b0;
        end
    end


    // =========================================================================
    // AXI WRITE CHANNEL
    // =========================================================================
    // FIX: The original design silently dropped bytes when buf_valid=1,
    // leaving the CPU stuck waiting for bvalid. Now we gate awready/wready
    // on !buf_valid so the CPU cannot start a write while the buffer is full.
    // This gives proper AXI backpressure and eliminates the deadlock.
    // =========================================================================
    reg       aw_got;
    reg       w_got;
    reg [7:0] w_byte;
    reg       b_vld;

    // Backpressure: don't accept new address/data while buffer is full
    assign s_axi_awready = !aw_got && !buf_valid;
    assign s_axi_wready  = !w_got  && !buf_valid;
    assign s_axi_bresp   = 2'b00;
    assign s_axi_bvalid  = b_vld;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            aw_got <= 1'b0;
            w_got  <= 1'b0;
            w_byte <= 8'h00;
            b_vld  <= 1'b0;
        end else begin

            // Capture write address (only when buffer has room)
            if (s_axi_awvalid && !aw_got && !buf_valid)
                aw_got <= 1'b1;

            // Capture write data (only when buffer has room)
            if (s_axi_wvalid && !w_got && !buf_valid) begin
                if      (s_axi_wstrb[0]) w_byte <= s_axi_wdata[ 7: 0];
                else if (s_axi_wstrb[1]) w_byte <= s_axi_wdata[15: 8];
                else if (s_axi_wstrb[2]) w_byte <= s_axi_wdata[23:16];
                else                     w_byte <= s_axi_wdata[31:24];
                w_got <= 1'b1;
            end

            // Both address and data latched → push byte to TX buffer and ack
            if (aw_got && w_got && !b_vld) begin
                buf_data  <= w_byte;
                buf_valid <= 1'b1;
                b_vld     <= 1'b1;
                aw_got    <= 1'b0;
                w_got     <= 1'b0;
            end

            // Complete AXI write response handshake
            if (b_vld && s_axi_bready)
                b_vld <= 1'b0;
        end
    end


    // =========================================================================
    // AXI READ CHANNEL
    // =========================================================================
    //
    // Memory map:
    //   Offset 0x0 / 0x4  → RX data register  {rx_buf_valid[8], data[7:0]}
    //   Offset 0x8        → Status register    {rx_buf_valid[1], tx_ready[0]}
    // =========================================================================
    reg        r_vld;
    reg [31:0] r_data;
    reg        r_is_stat;

    assign s_axi_arready = !r_vld;
    assign s_axi_rdata   = r_data;
    assign s_axi_rresp   = 2'b00;
    assign s_axi_rvalid  = r_vld;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_vld     <= 1'b0;
            r_data    <= 32'b0;
            r_is_stat <= 1'b0;
        end else begin

            if (s_axi_arvalid && !r_vld) begin
                r_vld     <= 1'b1;
                r_is_stat <= (s_axi_araddr[3:0] == 4'h8);

                if (s_axi_araddr[3:0] == 4'h8)
                    // Status: bit[1]=rx_buf_valid, bit[0]=tx_ready
                    r_data <= {30'b0, rx_buf_valid, tx_ready};
                else
                    // Data: bit[8]=rx_buf_valid (data-ready flag), bits[7:0]=byte
                    r_data <= {23'b0, rx_buf_valid, rx_buf_data};
            end

            if (r_vld && s_axi_rready)
                r_vld <= 1'b0;
        end
    end

endmodule