# =============================================================================
# Author       : Deepak
# Designation  : Sr. VLSI Engineer
# Organization : NIELIT CoE
# =============================================================================
# Makefile – PicoRV32 Memory-Mapped UART SoC
# =============================================================================
#
# Run from:  picorv32_uart_mem/
#
# Targets:
#   make fw     Build RISC-V firmware → rtl/rom.hex
#   make soc    Build firmware + Verilator compile + simulate
#   make wave   Convert VCD → FST and open GTKWave
#   make clean  Remove all build output
# =============================================================================

.DEFAULT_GOAL := help

# ── Directories (relative to picorv32_uart_mem/) ──────────────────────────────
RTL := rtl
TB  := tb
FW  := fw

# ── Tools ─────────────────────────────────────────────────────────────────────
VERILATOR := verilator
GTK       := gtkwave

# ── Verilator flags ────────────────────────────────────────────────────────────
VLFLAGS  = --binary -j 0 -Wall   \
            --trace               \
            --timing              \
            -Wno-fatal            \
            -Wno-WIDTHTRUNC       \
            -Wno-WIDTHEXPAND      \
            -Wno-PROCASSINIT      \
            -Wno-CASEINCOMPLETE   \
            -Wno-UNOPTFLAT        \
            -Wno-INITIALDLY       \
            -Wno-MULTITOP         \
            -Wno-DECLFILENAME     \
            -Wno-GENUNNAMED       \
            -Wno-UNUSEDSIGNAL     \
            -Wno-EOFNEWLINE       \
            -Wno-PINCONNECTEMPTY  \
            -Wno-BLKSEQ           \
            -Wno-PINMISSING       \
            -Wno-TIMESCALEMOD     \
            -Wno-CASEOVERLAP      \
            -Wno-SYNCASYNCNET     \
            -Wno-UNSIGNED         \
            -Wno-PROCASSWIRE      \
            -Wno-WIDTHXZEXPAND

# ── Help ───────────────────────────────────────────────────────────────────────
.PHONY: help
help:
	@echo "========================================================"
	@echo "  PicoRV32 Memory-Mapped UART SoC"
	@echo "========================================================"
	@echo ""
	@echo "  make fw     → Build RISC-V firmware   (rtl/rom.hex)"
	@echo "  make soc    → Firmware + Verilator sim (tb/tb_mem_soc.v)"
	@echo "  make wave   → Open GTKWave (tb_mem_soc.fst)"
	@echo "  make clean  → Remove all build output"
	@echo ""
	@echo "  Direct command (copy-paste):"
	@echo ""
	@echo "    rm -rf obj_mem/ && \\"
	@echo "    cd fw && make && cd .. && \\"
	@echo "    verilator --binary -j 0 -Wall \\"
	@echo "      --trace --timing \\"
	@echo "      --top tb_mem_soc \\"
	@echo "      -Mdir obj_mem \\"
	@echo "      -o sim_mem_soc \\"
	@echo "      -Wno-fatal -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND \\"
	@echo "      -Wno-PROCASSINIT -Wno-CASEINCOMPLETE -Wno-UNOPTFLAT \\"
	@echo "      -Wno-INITIALDLY -Wno-MULTITOP -Wno-DECLFILENAME \\"
	@echo "      -Wno-GENUNNAMED -Wno-UNUSEDSIGNAL -Wno-EOFNEWLINE \\"
	@echo "      -Wno-PINCONNECTEMPTY -Wno-BLKSEQ -Wno-PINMISSING \\"
	@echo "      rtl/picorv32.v rtl/uart_tx.v rtl/uart_rx.v \\"
	@echo "      rtl/mem_rom.v rtl/mem_sram.v rtl/uart_mem.v \\"
	@echo "      rtl/top.v tb/tb_mem_soc.v && \\"
	@echo "    ./obj_mem/sim_mem_soc +romhex=rtl/rom.hex && \\"
	@echo "    vcd2fst tb_mem_soc.vcd tb_mem_soc.fst && \\"
	@echo "    gtkwave tb_mem_soc.fst"
	@echo ""
	@echo "========================================================"

# ── Firmware ───────────────────────────────────────────────────────────────────
.PHONY: fw
fw:
	cd $(FW) && make

# ── SoC Simulation ─────────────────────────────────────────────────────────────
.PHONY: soc
soc:
	rm -rf obj_mem/
	cd $(FW) && make && cd .. && \
	$(VERILATOR) $(VLFLAGS)      \
	  --top tb_mem_soc           \
	  -Mdir obj_mem              \
	  -o sim_mem_soc             \
	  $(RTL)/picorv32.v          \
	  $(RTL)/uart_tx.v           \
	  $(RTL)/uart_rx.v           \
	  $(RTL)/mem_rom.v           \
	  $(RTL)/mem_sram.v          \
	  $(RTL)/uart_mem.v          \
	  $(RTL)/top.v               \
	  $(TB)/tb_mem_soc.v
	./obj_mem/sim_mem_soc +romhex=$(RTL)/rom.hex

# ── Waveform ───────────────────────────────────────────────────────────────────
.PHONY: wave
wave:
	vcd2fst tb_mem_soc.vcd tb_mem_soc.fst
	$(GTK) tb_mem_soc.fst &

# ── Clean ──────────────────────────────────────────────────────────────────────
.PHONY: clean
clean:
	rm -rf obj_mem/ *.vcd *.fst
	cd $(FW) && make clean
