// =============================================================
//  tb_processor.cpp  –  Verilator C++ Testbench for PicoRV32
//
//  DUT  : top  (top.v → Memory.v + picorv32.v)
//  Build: via Makefile  →  make verilator
//  Run  :                   ./obj_dir/Vtop
//  Wave :                   make wave
//
//  Program in code.hex (4 instructions):
//    addi  x10, x0,  2      → x10 = 2
//    addi  x10, x10, 5      → x10 = 7
//    addi  x11, x0,  32     → x11 = 32
//    sw    x10, 4(x11)      → MEM[36] = 7   (store result)
//    <illegal instr>        → trap asserts
// =============================================================

#include "Vtop.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <cstdio>
#include <cstdlib>

// Simulation limits
static const int MAX_CYCLES   = 300;   // cycles before force-stop
static const int POST_TRAP    = 20;    // extra cycles after trap (for waveform visibility)
static const int VCD_DEPTH    = 99;    // signal depth for VCD

// Timing
static vluint64_t sim_time   = 0;      // picoseconds
static const int  CLK_HALF   = 5;      // half-period in sim-time units

// ---- helpers -------------------------------------------------
static inline void tick(Vtop* dut, VerilatedVcdC* tfp)
{
    dut->eval();
    if (tfp) tfp->dump(sim_time);
    sim_time += CLK_HALF;

    dut->clk ^= 1;
    dut->eval();
    if (tfp) tfp->dump(sim_time);
    sim_time += CLK_HALF;
}

// ==============================================================
int main(int argc, char** argv)
{
    // ----------------------------------------------------------
    // 1. Initialise Verilator context
    // ----------------------------------------------------------
    const std::unique_ptr<VerilatedContext> ctx{new VerilatedContext};
    ctx->commandArgs(argc, argv);
    ctx->traceEverOn(true);   // must be before model creation

    printf("========================================\n");
    printf("  PicoRV32 Verilator Testbench\n");
    printf("  Built with Verilator %s\n", Verilated::productVersion());
    printf("========================================\n");

    // ----------------------------------------------------------
    // 2. Instantiate DUT
    // ----------------------------------------------------------
    Vtop* dut = new Vtop{ctx.get(), "TOP"};

    // ----------------------------------------------------------
    // 3. Open VCD trace
    // ----------------------------------------------------------
    VerilatedVcdC* tfp = new VerilatedVcdC;
    dut->trace(tfp, VCD_DEPTH);
    tfp->open("tb_picorv32.vcd");
    printf("[TB] VCD trace → tb_picorv32.vcd\n");

    // ----------------------------------------------------------
    // 4. Reset sequence  (mirrors tb_processor.v)
    //    rst_n=X for 3 cycles → rst_n=1 for 3 cycles →
    //    rst_n=0 for 5 cycles → rst_n=1 → run
    // ----------------------------------------------------------
    dut->clk     = 0;
    dut->reset_n = 0;

    // De-assert reset after 10 half-ticks
    for (int i = 0; i < 10; i++) {
        dut->clk ^= 1;
        dut->eval();
        if (tfp) tfp->dump(sim_time);
        sim_time += CLK_HALF;
    }
    dut->reset_n = 1;
    printf("[TB] Reset de-asserted at t=%llu\n", (unsigned long long)sim_time);

    // ----------------------------------------------------------
    // 5. Run simulation — stop on trap OR max-cycles
    // ----------------------------------------------------------
    int  cycle          = 0;
    int  post_trap_ctr  = 0;
    bool trap_seen      = false;

    while (cycle < MAX_CYCLES) {
        tick(dut, tfp);

        // Sample on rising edge (clk just went HIGH inside tick,
        // so clk==1 now)
        if (dut->clk == 1) {
            cycle++;

            // Print bus transactions every rising edge
            if (dut->mem_valid) {
                if (dut->mem_wstrb != 0) {
                    printf("[TB] cycle %3d  WRITE  addr=0x%08X  data=0x%08X  strb=%X\n",
                           cycle,
                           (unsigned)dut->mem_addr,
                           (unsigned)dut->mem_wdata,
                           (unsigned)dut->mem_wstrb);
                } else {
                    printf("[TB] cycle %3d  READ   addr=0x%08X  rdata=0x%08X\n",
                           cycle,
                           (unsigned)dut->mem_addr,
                           (unsigned)dut->mem_rdata);
                }
            }

            // Trap detection — run POST_TRAP extra cycles then stop
            if (dut->trap && !trap_seen) {
                trap_seen = true;
                printf("[TB] *** TRAP asserted at cycle %d ***\n", cycle);
                printf("[TB] Last mem_addr  = 0x%08X\n", (unsigned)dut->mem_addr);
                printf("[TB] Last mem_rdata = 0x%08X\n", (unsigned)dut->mem_rdata);
            }
            if (trap_seen) {
                if (++post_trap_ctr >= POST_TRAP) break;
            }
        }
    }

    // ----------------------------------------------------------
    // 6. Result
    // ----------------------------------------------------------
    if (trap_seen) {
        printf("[TB] SIMULATION PASSED — processor trapped as expected\n");
        printf("[TB] Total cycles run: %d\n", cycle);
    } else {
        printf("[TB] WARNING — reached MAX_CYCLES (%d) without trap\n", MAX_CYCLES);
        printf("[TB] SIMULATION INCOMPLETE\n");
    }

    // ----------------------------------------------------------
    // 7. Cleanup
    // ----------------------------------------------------------
    tfp->close();
    delete tfp;
    delete dut;

    printf("========================================\n");
    return trap_seen ? 0 : 1;
}
