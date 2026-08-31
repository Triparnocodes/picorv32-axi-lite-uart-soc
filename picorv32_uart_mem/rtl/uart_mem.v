/*
------------------------------------------------------------------------------
 Author       : Deepak
 Designation  : Sr. VLSI Engineer
 Organization : NIELIT CoE
------------------------------------------------------------------------------

MODULE OVERVIEW
---------------
Memory-Mapped UART Peripheral — PicoRV32 native bus interface.

REGISTER MAP (offset from base address 0x1000_0000)
---------------------------------------------------
  Offset 0x0  UART_TX   [7:0]  Write-Only   Write byte → triggers TX
  Offset 0x4  UART_RX   [7:0]  Read-Only    Read received byte (clears rx_valid)
  Offset 0x8  UART_STAT [1:0]  Read-Only    [1]=rx_valid  [0]=tx_ready

TX_READY (UART_STAT[0]) = !tx_buf_valid
  Firmware can write when the 1-byte TX buffer is empty.

SINGLE-DRIVER RULE (no multi-driven regs):
  tx_buf_valid  → driven ONLY by always_tx block
  tx_buf_data   → driven ONLY by always_tx block
  rx_buf_valid  → driven ONLY by always_rx block
  rx_buf_data   → driven ONLY by always_rx block
  rx_rd_strobe  → driven ONLY by always_tx block (read by always_rx)

ASIC-clean: no initial blocks, no inline reg initializers.
*/

`timescale 1ns / 1ps

module uart_mem #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115_200
)(
    input              clk,
    input              reset,

    input              mem_valid,
    output reg         mem_ready,
    input       [31:0] mem_addr,
    input       [31:0] mem_wdata,
    input       [ 3:0] mem_wstrb,
    output reg  [31:0] mem_rdata,

    output             uart_tx,
    input              uart_rx
);

    // =========================================================================
    // UART TX core
    // =========================================================================
    reg  [7:0] tx_data;
    reg        tx_valid;
    wire       tx_ready;

    (* keep *) wire tx_serial_out;
    assign uart_tx = tx_serial_out;

    uart_tx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_tx (
        .clk   (clk),
        .reset (reset),
        .data  (tx_data),
        .valid (tx_valid),
        .ready (tx_ready),
        .tx    (tx_serial_out)
    );

    // =========================================================================
    // UART RX core
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
    // Decode helpers (combinatorial, no reg)
    // =========================================================================
    wire [1:0] reg_sel  = mem_addr[3:2];
    wire       is_write = mem_valid && (|mem_wstrb);
    wire       is_read  = mem_valid && !(|mem_wstrb);

    wire [7:0] wr_byte =
        mem_wstrb[0] ? mem_wdata[ 7: 0] :
        mem_wstrb[1] ? mem_wdata[15: 8] :
        mem_wstrb[2] ? mem_wdata[23:16] :
                       mem_wdata[31:24];

    // =========================================================================
    // RX 1-byte buffer  (always_rx — owns rx_buf_valid, rx_buf_data)
    // =========================================================================
    reg [7:0] rx_buf_data;
    reg       rx_buf_valid;
    reg       rx_rd_strobe;   // written by always_tx, read here

    // always_rx : SINGLE DRIVER for rx_buf_valid and rx_buf_data
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_buf_data  <= 8'h00;
            rx_buf_valid <= 1'b0;
        end else begin
            // New byte captured from RX core (highest priority)
            if (rx_data_valid_pulse) begin
                rx_buf_data  <= rx_data_raw;
                rx_buf_valid <= 1'b1;
            end else if (rx_rd_strobe) begin
                // CPU read of UART_RX completed — clear valid
                rx_buf_valid <= 1'b0;
            end
        end
    end

    // =========================================================================
    // TX 1-byte buffer + Drain + Bus interface  (always_tx)
    // =========================================================================
    // SINGLE DRIVER for: tx_buf_valid, tx_buf_data, tx_valid, tx_data,
    //                    wr_state, wr_pending_data, mem_ready, mem_rdata,
    //                    rx_rd_strobe
    // =========================================================================
    localparam TX_IDLE = 1'b0;
    localparam TX_WAIT = 1'b1;

    reg        wr_state;
    reg [7:0]  wr_pending_data;
    reg [7:0]  tx_buf_data;
    reg        tx_buf_valid;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tx_valid        <= 1'b0;
            tx_data         <= 8'h00;
            tx_buf_valid    <= 1'b0;
            tx_buf_data     <= 8'h00;
            wr_state        <= TX_IDLE;
            wr_pending_data <= 8'h00;
            mem_ready       <= 1'b0;
            mem_rdata       <= 32'h0;
            rx_rd_strobe    <= 1'b0;
        end else begin
            // ── Defaults ────────────────────────────────────────────────────
            tx_valid     <= 1'b0;
            mem_ready    <= 1'b0;
            rx_rd_strobe <= 1'b0;

            // ── Drain: forward TX buffer to uart_tx core ─────────────────────
            if (tx_ready && tx_buf_valid) begin
                tx_data      <= tx_buf_data;
                tx_valid     <= 1'b1;
                tx_buf_valid <= 1'b0;
            end

            // ── Bus FSM ──────────────────────────────────────────────────────
            case (wr_state)

                TX_IDLE: begin
                    if (mem_valid && !mem_ready) begin
                        if (is_write) begin
                            // WRITE to UART_TX
                            wr_pending_data <= wr_byte;

                            if (!tx_buf_valid) begin
                                // Buffer free — load immediately
                                tx_buf_data  <= wr_byte;
                                tx_buf_valid <= 1'b1;
                                mem_ready    <= 1'b1;
                            end else begin
                                // Buffer busy — stall CPU
                                wr_state <= TX_WAIT;
                            end

                        end else begin
                            // READ
                            mem_ready <= 1'b1;
                            case (reg_sel)
                                2'b01: begin
                                    // UART_RX: return byte, clear on next cycle
                                    mem_rdata    <= {24'h0, rx_buf_data};
                                    rx_rd_strobe <= 1'b1;
                                end
                                2'b10: begin
                                    // UART_STAT
                                    // [0] = !tx_buf_valid (buffer empty = ready)
                                    // [1] = rx_buf_valid
                                    mem_rdata <= {30'h0, rx_buf_valid,
                                                         !tx_buf_valid};
                                end
                                default: mem_rdata <= 32'h0;
                            endcase
                        end
                    end
                end

                TX_WAIT: begin
                    // Wait for drain to empty the buffer
                    if (!tx_buf_valid) begin
                        tx_buf_data  <= wr_pending_data;
                        tx_buf_valid <= 1'b1;
                        mem_ready    <= 1'b1;
                        wr_state     <= TX_IDLE;
                    end
                end

                default: wr_state <= TX_IDLE;

            endcase
        end
    end

endmodule
