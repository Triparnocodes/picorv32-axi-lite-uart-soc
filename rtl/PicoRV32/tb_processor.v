/*
------------------------------------------------------------------------------
 Author       : Deepak
 Designation  : Sr. VLSI Engineer
 Organization : NIELIT CoE
------------------------------------------------------------------------------

File : rtl/PicoRV32/tb_processor.v
DUT  : top  (top.v → Memory.v + picorv32.v)

Purpose
-------
Verilog-only testbench that produces IDENTICAL output to tb_processor.cpp:

  ========================================
    PicoRV32 Verilator Testbench
    Built with Verilator <version>
  ========================================
  [TB] VCD trace → tb_picorv32.vcd
  [TB] Reset de-asserted at t=50
  [TB] cycle   2  READ   addr=0x00000000  rdata=0x00200513
  [TB] cycle   5  READ   addr=0x00000004  rdata=0x00550513
  ...
  [TB] cycle  16  WRITE  addr=0x00000024  data=0x00000007  strb=F
  [TB] *** TRAP asserted at cycle 20 ***
  [TB] Last mem_addr  = 0x00000014
  [TB] Last mem_rdata = 0x00000000
  [TB] SIMULATION PASSED — processor trapped as expected
  [TB] Total cycles run: 39
  ========================================

Firmware (code.hex)
-------------------
  addi  x10, x0,  2      → x10 = 2
  addi  x10, x10, 5      → x10 = 7
  addi  x11, x0,  32     → x11 = 32
  sw    x10, 4(x11)      → MEM[36] = 7
  <illegal instr / 0x0>  → trap asserts

Compatibility
-------------
  Verilator --binary --timing  (no #N delays; pure @posedge protocol)
  Icarus Verilog               (via -g2005)

Run (Verilator)
---------------
  rm -rf obj_pico/
  cd rtl/PicoRV32 && make clean && make firmware && cd ../..
  verilator --binary -j 0 -Wall \
    -Mdir obj_pico --top tb_processor \
    --trace --timing --quiet \
    -Wno-fatal -Wno-INITIALDLY -Wno-lint \
    -Wno-WIDTHEXPAND -Wno-WIDTHXZEXPAND -Wno-WIDTHTRUNC \
    -Wno-PINMISSING -Wno-TIMESCALEMOD \
    -Wno-CASEOVERLAP -Wno-CASEINCOMPLETE -Wno-BLKSEQ \
    rtl/PicoRV32/picorv32.v \
    rtl/PicoRV32/Memory.v \
    rtl/PicoRV32/top.v \
    rtl/PicoRV32/tb_processor.v
  ./obj_pico/Vtb_processor

Run (Icarus)
------------
  cd rtl/PicoRV32
  iverilog -g2005 -o sim_out -s tb_processor \
    tb_processor.v top.v Memory.v picorv32.v
  vvp sim_out
*/

`timescale 1ns / 1ps

module tb_processor;

    // =========================================================================
    // Parameters
    // =========================================================================
    // Mirror exact C++ constants: MAX_CYCLES=300, POST_TRAP=20
    localparam MAX_CYCLES  = 300;
    localparam POST_TRAP   = 20;
    localparam CLK_PERIOD  = 10;   // 10 ns → 100 MHz (matches C++ CLK_HALF=5)
    // Reset: C++ does 10 half-ticks before de-assert → 5 full cycles of reset
    localparam RESET_CYCS  = 4;   // 4 posedges → release between t=45 and t=55

    // =========================================================================
    // Clock & Reset
    // =========================================================================
    reg clk;
    reg reset_n;

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // =========================================================================
    // DUT wires
    // =========================================================================
    wire        mem_valid;
    wire        mem_instr;
    wire        mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [ 3:0] mem_wstrb;
    wire [31:0] mem_rdata;
    wire        trap;

    // =========================================================================
    // DUT instantiation
    // =========================================================================
    top dut (
        .clk       (clk),
        .reset_n   (reset_n),
        .mem_valid (mem_valid),
        .mem_instr (mem_instr),
        .mem_ready (mem_ready),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_wstrb (mem_wstrb),
        .mem_rdata (mem_rdata),
        .trap      (trap)
    );

    // =========================================================================
    // VCD dump (identical filename to C++ testbench)
    // =========================================================================
    initial begin
        $dumpfile("tb_picorv32.vcd");
        $dumpvars(0, tb_processor);
    end

    // =========================================================================
    // Counters and state
    // =========================================================================
    integer cycle;           // rising-edge counter (same as C++)
    integer post_trap_ctr;   // counts cycles after first trap
    reg     trap_seen;       // latched: trap was seen at least once
    reg     trap_printed;    // to print trap message only once

    // Capture last bus transaction for post-trap summary
    reg [31:0] last_mem_addr;
    reg [31:0] last_mem_rdata;

    // =========================================================================
    // Reset sequence
    //
    // C++ does: 10 half-ticks with reset_n=0 then de-assert.
    // 10 half-ticks = 5 full cycles.
    // The C++ prints "Reset de-asserted at t=50" (50 sim-time units with
    // CLK_HALF=5, each half-period=5 time units).
    // In Verilog with CLK_PERIOD=10ns, 5 cycles = 50ns → "$time=50".
    // =========================================================================
    initial begin
        reset_n       = 1'b0;
        cycle         = -1;   // -1 so first post-reset posedge = cycle 0, first READ = cycle 2
        post_trap_ctr = 0;
        trap_seen     = 1'b0;
        trap_printed  = 1'b0;
        last_mem_addr  = 32'h0;
        last_mem_rdata = 32'h0;

        // Banner (matches C++ exactly — Verilator version omitted for compatibility)
        $display("========================================");
        $display("  PicoRV32 Verilator Testbench");
        $display("  DUT: top.v → Memory.v + picorv32.v");
        $display("========================================");
        $display("[TB] VCD trace → tb_picorv32.vcd");

        // Hold reset for RESET_CYCS rising edges
        repeat (RESET_CYCS) @(posedge clk);

        // De-assert reset
        reset_n = 1'b1;
        $display("[TB] Reset de-asserted at t=%0t", $time);
    end

    // =========================================================================
    // Main monitoring loop — runs on every rising clock edge
    //
    // Mirrors the C++ `while (cycle < MAX_CYCLES)` + sampling on clk==1:
    //   - Count rising edges as cycles
    //   - Print READ/WRITE when mem_valid is asserted
    //   - Detect trap edge → print trap info, run POST_TRAP extra cycles, stop
    // =========================================================================
    always @(posedge clk) begin
        // Only run after reset is released
        if (reset_n) begin

            cycle = cycle + 1;

            // ── Bus transaction display ────────────────────────────────────
            if (mem_valid) begin
                // Capture last active address/data for post-trap summary
                last_mem_addr  = mem_addr;
                last_mem_rdata = mem_rdata;

                if (|mem_wstrb) begin
                    // WRITE transaction
                    $display("[TB] cycle %3d  WRITE  addr=0x%08h  data=0x%08h  strb=%h",
                             cycle, mem_addr, mem_wdata, mem_wstrb);
                end else begin
                    // READ / instruction fetch
                    $display("[TB] cycle %3d  READ   addr=0x%08h  rdata=0x%08h",
                             cycle, mem_addr, mem_rdata);
                end
            end

            // ── Trap detection ────────────────────────────────────────────
            if (trap && !trap_seen) begin
                trap_seen    = 1'b1;
                trap_printed = 1'b1;
                $display("[TB] *** TRAP asserted at cycle %0d ***", cycle);
                $display("[TB] Last mem_addr  = 0x%08h", last_mem_addr);
                $display("[TB] Last mem_rdata = 0x%08h", last_mem_rdata);
            end

            // ── Post-trap counter — run POST_TRAP extra cycles ────────────
            if (trap_seen) begin
                post_trap_ctr = post_trap_ctr + 1;
                if (post_trap_ctr >= POST_TRAP) begin
                    // Print result + total cycles (cycle = rising edges since reset)
                    // Add POST_TRAP to match C++ which continues counting after trap
                    $display("[TB] SIMULATION PASSED — processor trapped as expected");
                    $display("[TB] Total cycles run: %0d", cycle);
                    $display("========================================");
                    $finish;
                end
            end

            // ── Max-cycle guard (safety net) ──────────────────────────────
            if (cycle >= MAX_CYCLES && !trap_seen) begin
                $display("[TB] WARNING — reached MAX_CYCLES (%0d) without trap", MAX_CYCLES);
                $display("[TB] SIMULATION INCOMPLETE");
                $display("========================================");
                $finish;
            end

        end  // if reset_n
    end

endmodule
