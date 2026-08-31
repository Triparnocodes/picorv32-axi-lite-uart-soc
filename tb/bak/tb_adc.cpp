/*
------------------------------------------------------------------------------
 Author       : Deepak
 Designation  : Sr. VLSI Engineer
 Organization : NIELIT CoE
------------------------------------------------------------------------------

File: tb_adc.cpp

Purpose
-------
Standalone Verilator C++ testbench for the 8-bit SAR ADC.

This testbench uses adc_tb_wrap (which wraps sar_adc_axi + adc_controller)
and drives the AXI-Lite interface directly from C++ — no firmware needed.

What it does:
  1. Resets the DUT.
  2. For each test vector (vin):
       a. Writes 1 to CTRL register (0x00) → starts ADC conversion.
       b. Every clock, drives comp_in = (vin > dac_out).
       c. Monitors FSM state and prints per-bit debug info:
            [Bit X]  trial=YYY (0xZZ)  comp=C  sar=0xRR
       d. Polls STATUS until done = 1.
       e. Reads DATA register to get ADC result.
       f. Prints: Expected, Got, Error, PASS/FAIL.
  3. Prints overall summary.

HOW THE ANALOG COMPARATOR IS MODELLED
--------------------------------------
In a real SAR ADC:
  comp_out = 1  if  vin >= V_trial
  comp_out = 0  if  vin <  V_trial

In simulation:
  dac_out = trial DAC code (0–255 for 8-bit)
  vin     = known integer (test vector)

So: comp_in = (vin > dac_out)

This perfectly replicates the comparator's role in the binary search.

AXI-Lite register map (base: irrelevant for wrapper, offset-only):
  0x00 - CTRL   (write 1 to start)
  0x04 - STATUS ([0]=done, [1]=busy)
  0x08 - DATA   (8-bit result)

Compile with: make adc_sim
*/

// =============================================================================
// tb_adc.cpp – SAR ADC Verilator C++ Testbench (standalone, no CPU needed)
// =============================================================================

#include "Vadc_tb_wrap.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <cstdint>
#include <cstdio>

// ─────────────────────────────────────────────────────────────────────────────
// AXI Register Offsets (used as 32-bit addresses in the wrapper)
// ─────────────────────────────────────────────────────────────────────────────
#define REG_CTRL    0x00   // write 1 to start
#define REG_STATUS  0x04   // [0]=done, [1]=busy
#define REG_DATA    0x08   // 8-bit result

// ─────────────────────────────────────────────────────────────────────────────
// Simulation Globals
// ─────────────────────────────────────────────────────────────────────────────
#define RESET_CYCLES  20
#define MAX_WAIT      1000   // max cycles to wait per AXI transaction

static vluint64_t   sim_time = 0;
static Vadc_tb_wrap *dut     = nullptr;
static VerilatedVcdC *tfp    = nullptr;

double sc_time_stamp() { return (double)sim_time; }

// ─────────────────────────────────────────────────────────────────────────────
// Current test vector (global so comparator model can access it)
// ─────────────────────────────────────────────────────────────────────────────
static uint8_t g_vin = 0;

// ─────────────────────────────────────────────────────────────────────────────
// Clock tick — also drives comp_in every cycle
// ─────────────────────────────────────────────────────────────────────────────
// static void tick()
// {
//     // Drive comparator: comp_in = 1 if vin > dac_out
//     // (vin > dac_out means vin is above the trial level → keep this bit)
//     dut->comp_in = (g_vin > dut->dac_out) ? 1 : 0;

//     dut->clk = 0;
//     dut->eval();
//     if (tfp) tfp->dump(sim_time);
//     sim_time++;

//     // Re-drive comp_in on rising edge too (combinational comparator)
//     dut->comp_in = (g_vin > dut->dac_out) ? 1 : 0;

//     dut->clk = 1;
//     dut->eval();
//     if (tfp) tfp->dump(sim_time);
//     sim_time++;
// }


static void tick()
{
    dut->vin_debug = g_vin;   // NEW

    dut->clk = 0;
    dut->eval();
    if (tfp) tfp->dump(sim_time);
    sim_time++;

    dut->vin_debug = g_vin;   // keep stable

    dut->clk = 1;
    dut->eval();
    if (tfp) tfp->dump(sim_time);
    sim_time++;
}



// ─────────────────────────────────────────────────────────────────────────────
// AXI-Lite Write
// ─────────────────────────────────────────────────────────────────────────────
static void axi_write(uint32_t addr, uint32_t data)
{
    // Drive AW and W simultaneously
    dut->s_axi_awaddr  = addr;
    dut->s_axi_awvalid = 1;
    dut->s_axi_wdata   = data;
    dut->s_axi_wstrb   = 0xF;
    dut->s_axi_wvalid  = 1;
    dut->s_axi_bready  = 0;

    // Wait for AW handshake
    int wait = 0;
    while (!dut->s_axi_awready && wait++ < MAX_WAIT) tick();
    tick();                         // one tick for handshake to complete
    dut->s_axi_awvalid = 0;

    // Wait for W handshake
    wait = 0;
    while (!dut->s_axi_wready && wait++ < MAX_WAIT) tick();
    tick();
    dut->s_axi_wvalid = 0;

    // Accept write response
    dut->s_axi_bready = 1;
    wait = 0;
    while (!dut->s_axi_bvalid && wait++ < MAX_WAIT) tick();
    tick();
    dut->s_axi_bready = 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// AXI-Lite Read
// ─────────────────────────────────────────────────────────────────────────────
static uint32_t axi_read(uint32_t addr)
{
    dut->s_axi_araddr  = addr;
    dut->s_axi_arvalid = 1;
    dut->s_axi_rready  = 1;

    // Wait for AR handshake
    int wait = 0;
    while (!dut->s_axi_arready && wait++ < MAX_WAIT) tick();
    tick();
    dut->s_axi_arvalid = 0;

    // Wait for R data
    wait = 0;
    while (!dut->s_axi_rvalid && wait++ < MAX_WAIT) tick();
    uint32_t rdata = dut->s_axi_rdata;
    tick();
    dut->s_axi_rready = 0;

    return rdata;
}

// ─────────────────────────────────────────────────────────────────────────────
// Run a Complete SAR ADC Conversion
// ─────────────────────────────────────────────────────────────────────────────
static int run_conversion(uint8_t vin)
{
    g_vin = vin;   // update comparator model

    printf("\n");
    printf("┌──────────────────────────────────────────────────────┐\n");
    printf("│  SAR ADC Conversion   vin = %3u  (0x%02X)              │\n", vin, vin);
    printf("├──────┬──────────────┬─────────┬──────────────────────┤\n");
    printf("│ Bit  │  Trial DAC   │ comp_in │  SAR Register        │\n");
    printf("├──────┼──────────────┼─────────┼──────────────────────┤\n");

    // Start conversion: write 1 to CTRL
    axi_write(REG_CTRL, 1);

    // Monitor the binary search step by step
    // Each bit takes 1 clock cycle in the CONVERTING state (state=1)
    int  prev_bit   = 10;   // sentinel
    bool done_seen  = false;

    for (int cyc = 0; cyc < 200 && !done_seen; cyc++) {
        dut->eval();

        int     cur_state = (int) dut->dbg_state;
        int     cur_bit   = (int) dut->dbg_bit;
        uint8_t cur_sar   = (uint8_t) dut->dbg_sar;
        uint8_t cur_dac   = (uint8_t) dut->dac_out;
        int     comp      = (int) dut->comp_in;

        if (cur_state == 1 /* CONVERTING */ && cur_bit != prev_bit) {
            printf("│  %2d  │  %3u  (0x%02X) │    %d    │  0x%02X = " , 
                   cur_bit, cur_dac, cur_dac, comp, cur_sar);
            // Print binary for SAR register
            for (int b = 7; b >= 0; b--)
                printf("%d", (cur_sar >> b) & 1);
            printf("     │\n");
            prev_bit = cur_bit;
        }

        if (cur_state == 2 /* DONE */) {
            done_seen = true;
        }

        tick();
    }

    printf("└──────┴──────────────┴─────────┴──────────────────────┘\n");

    // Give a few extra cycles for the result to latch
    for (int i = 0; i < 5; i++) tick();

    // Read STATUS
    uint32_t status = axi_read(REG_STATUS);

    // Read DATA
    uint32_t result_word = axi_read(REG_DATA);
    uint8_t  result      = (uint8_t)(result_word & 0xFF);

    // Compute error
    int      error       = (int)vin - (int)result;
    int      abs_error   = (error < 0) ? -error : error;
    int      pass        = (abs_error <= 1);

    printf("\n  STATUS = 0x%08X  |  done=%d  busy=%d\n",
           status, (int)(status & 1), (int)((status >> 1) & 1));
    printf("  Expected  : %3u  (0x%02X)\n", vin, vin);
    printf("  Got       : %3u  (0x%02X)\n", result, result);
    printf("  Error     : %+d LSB\n", error);
    printf("  Result    : %s\n", pass ? ">>> PASS ✓" : ">>> FAIL ✗");
    printf("────────────────────────────────────────────────────────\n");

    return pass;
}

// ─────────────────────────────────────────────────────────────────────────────
// main()
// ─────────────────────────────────────────────────────────────────────────────
int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);

    dut = new Vadc_tb_wrap;

    Verilated::traceEverOn(true);
    tfp = new VerilatedVcdC;
    dut->trace(tfp, 99);
    tfp->open("tb_adc.vcd");

    // ── Initialize all inputs ──────────────────────────────────────────────
    dut->clk           = 0;
    dut->reset         = 1;
    dut->comp_in       = 0;
    dut->s_axi_awvalid = 0;
    dut->s_axi_awaddr  = 0;
    dut->s_axi_wdata   = 0;
    dut->s_axi_wstrb   = 0;
    dut->s_axi_wvalid  = 0;
    dut->s_axi_bready  = 0;
    dut->s_axi_araddr  = 0;
    dut->s_axi_arvalid = 0;
    dut->s_axi_rready  = 0;
    dut->vin_debug = g_vin;

    printf("╔═══════════════════════════════════════════════════════╗\n");
    printf("║  8-bit SAR ADC  –  Verilator Simulation               ║\n");
    printf("║  NIELIT CoE                                           ║\n");
    printf("╚═══════════════════════════════════════════════════════╝\n");

    // ── Reset ──────────────────────────────────────────────────────────────
    for (int i = 0; i < RESET_CYCLES; i++) tick();
    dut->reset = 0;
    tick(); tick();

    printf("\n[TB] Reset released. Running conversions...\n");

    // ── Test Vectors ───────────────────────────────────────────────────────
    // These cover: typical mid-range, alternating bits, edge cases, random
    uint8_t tests[] = { 170, 85, 255, 0, 128, 200, 63, 42 };
    int num_tests   = (int)(sizeof(tests) / sizeof(tests[0]));
    int passed      = 0;

    for (int i = 0; i < num_tests; i++) {
        if (run_conversion(tests[i]))
            passed++;

        // Brief idle between conversions
        for (int j = 0; j < 8; j++) {
            g_vin = 0;
            tick();
        }
    }

    // ── Final Summary ──────────────────────────────────────────────────────
    printf("\n╔═══════════════════════════════════════════════════════╗\n");
    printf("║  SIMULATION SUMMARY                                   ║\n");
    printf("╠═══════════════════════════════════════════════════════╣\n");
    printf("║  Tests run    : %-5d                                 ║\n", num_tests);
    printf("║  Tests passed : %-5d                                 ║\n", passed);
    printf("║  Tests failed : %-5d                                 ║\n", num_tests - passed);
    printf("║  Sim cycles   : %-10llu                            ║\n", (unsigned long long)sim_time);
    printf("╠═══════════════════════════════════════════════════════╣\n");
    if (passed == num_tests)
        printf("║  *** ALL TESTS PASSED ✓ ***                           ║\n");
    else
        printf("║  *** SOME TESTS FAILED ✗ ***                          ║\n");
    printf("╚═══════════════════════════════════════════════════════╝\n");

    tfp->close();
    delete tfp;
    delete dut;

    return (passed == num_tests) ? 0 : 1;
}
