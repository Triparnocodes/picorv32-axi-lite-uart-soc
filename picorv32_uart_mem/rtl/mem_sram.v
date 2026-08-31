/*
------------------------------------------------------------------------------
 Author       : Deepak
 Designation  : Sr. VLSI Engineer
 Organization : NIELIT CoE
------------------------------------------------------------------------------

MODULE OVERVIEW
---------------
SRAM (Read/Write) with PicoRV32 native memory bus interface.

Replaces AXI-Lite sram.v with a direct native-bus version.
Supports byte-enable writes via mem_wstrb[3:0].

Protocol:
  Write: mem_valid=1, mem_wstrb!=0  → mem_ready asserted same cycle (1-cycle)
  Read : mem_valid=1, mem_wstrb==0  → mem_ready + mem_rdata next cycle (1-cycle)

ASIC-clean:
  - No inline reg initializers
  - No initial blocks (SRAM undefined at power-on — firmware initializes)
  - Byte-enable write support
*/

`timescale 1ns / 1ps

module mem_sram #(
    parameter MEM_DEPTH = 64           // Number of 32-bit words (256 B)
)(
    input              clk,
    input              reset,

    // PicoRV32 native memory bus (read/write slave)
    input              mem_valid,      // CPU has a valid request
    output reg         mem_ready,      // SRAM response ready
    input       [31:0] mem_addr,       // Byte address from CPU
    input       [31:0] mem_wdata,      // Write data from CPU
    input       [ 3:0] mem_wstrb,      // Byte write strobes (0=read, else write)
    output reg  [31:0] mem_rdata       // Read data to CPU
);

    // -------------------------------------------------------------------------
    // Memory array — undefined at power-on (ASIC-correct behaviour)
    // -------------------------------------------------------------------------
    reg [31:0] mem [0:MEM_DEPTH-1];

    // Word index from byte address
    wire [$clog2(MEM_DEPTH)-1:0] widx = mem_addr[$clog2(MEM_DEPTH)+1 : 2];

    // -------------------------------------------------------------------------
    // Read/Write FSM — single-cycle response
    // -------------------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mem_ready <= 1'b0;
            mem_rdata <= 32'h0;
        end else begin
            mem_ready <= 1'b0;

            if (mem_valid && !mem_ready) begin
                if (|mem_wstrb) begin
                    // ── WRITE with byte enables ───────────────────────────
                    if (mem_wstrb[0]) mem[widx][ 7: 0] <= mem_wdata[ 7: 0];
                    if (mem_wstrb[1]) mem[widx][15: 8] <= mem_wdata[15: 8];
                    if (mem_wstrb[2]) mem[widx][23:16] <= mem_wdata[23:16];
                    if (mem_wstrb[3]) mem[widx][31:24] <= mem_wdata[31:24];
                    mem_ready <= 1'b1;
                end else begin
                    // ── READ ─────────────────────────────────────────────
                    mem_rdata <= mem[widx];
                    mem_ready <= 1'b1;
                end
            end
        end
    end

endmodule
