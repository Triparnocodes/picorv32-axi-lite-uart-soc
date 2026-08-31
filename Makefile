# =============================================================================
# Author       : Deepak
# Designation  : Sr. VLSI Engineer
# Organization : NIELIT CoE
# =============================================================================
# Makefile – Verilog TB ONLY (Verilator --binary flow)
# =============================================================================

# =========================================================
# DEFAULT TARGET → SHOW HELP
# =========================================================
.DEFAULT_GOAL := help

# =========================================================
# Conditional GTKWave launch
# Set OPEN_WAVE=0 to suppress GTKWave GUI (used by make all)
# Default: OPEN_WAVE=1  →  individual targets open GTKWave
# =========================================================
OPEN_WAVE ?= 1

# =========================================================
# ALL — run every simulation without opening GTKWave
# =========================================================
.PHONY: all
all:
	$(MAKE) OPEN_WAVE=0 fw
	$(MAKE) OPEN_WAVE=0 uart
	$(MAKE) OPEN_WAVE=0 pico
	$(MAKE) OPEN_WAVE=0 riscv_axi
	$(MAKE) OPEN_WAVE=0 axi_uart
	$(MAKE) OPEN_WAVE=0 axi_sa
	$(MAKE) OPEN_WAVE=0 soc_pico_uart_mem
	$(MAKE) OPEN_WAVE=0 soc
	$(MAKE) OPEN_WAVE=0 debug_soc

# =========================================================
# Directories
# =========================================================
ROOT      := $(shell pwd)
RTL       := $(ROOT)/rtl
TB        := $(ROOT)/tb
FW        := $(ROOT)/fw
OPENLANE  := $(ROOT)/openlane_design

# =========================================================
# Tools
# =========================================================
VERILATOR := verilator
GTK       := gtkwave


# =========================================================
# Common Flags (Verilog TB Flow)
# =========================================================
VLFLAGS = --binary -j 0 -Wall \
          --trace --timing \
          -Wno-fatal \
          -Wno-WIDTHTRUNC \
          -Wno-WIDTHEXPAND \
          -Wno-CASEINCOMPLETE \
          -Wno-UNOPTFLAT \
          -Wno-INITIALDLY \
          -Wno-PINMISSING \
          -Wno-UNSIGNED \
          -Wno-SYNCASYNCNET \
          -Wno-DECLFILENAME \
          -Wno-GENUNNAMED \
          -Wno-UNUSEDSIGNAL \
          -Wno-PINCONNECTEMPTY \
          -Wno-TIMESCALEMOD \
          -Wno-CASEOVERLAP \
          -Wno-BLKSEQ \
          -Wno-EOFNEWLINE \
          -Wno-PROCASSWIRE \
          -Wno-WIDTHXZEXPAND 
          

# =========================================================
# HELP MENU
# =========================================================
.PHONY: help
help:
		@echo "================ AVAILABLE COMMANDS ================"
	@echo ""

	@echo "UART:"
	@echo "  make uart                   → Run UART (Verilog TB)"
	@echo ""

	@echo "PicoRV32:"
	@echo "  make pico                   → Run PicoRV32 (Verilog TB)"
	@echo ""

	@echo "RISC-V AXI-Lite Integration:"
	@echo "  make riscv_axi              → AXI-Lite handshake demo TB"
	@echo ""

	@echo "AXI-Lite:"
	@echo "  make axi_uart               → Run AXI-Lite - UART (Verilog TB)"
	@echo "  make axi_sa                 → AXI-Lite standalone TB"
	@echo ""

	@echo "Firmware Build:"
	@echo "  make fw                     → Build firmware"
	@echo ""

	@echo "SoC:"
	@echo "  make soc_pico_uart_mem      → Build FW + Verilator sim (mem-mapped UART)"
	@echo "  make soc                    → Run full PicoRV32 + UART + AXI (AXI design)"
	@echo ""

	@echo "Waveform View:"
	@echo "  make wave                   → Open waveform"
	@echo ""

	@echo "Synthesis:"
	@echo "  make synth                  → Run Yosys synthesis"
#	@echo "  make openlane               → Run OpenLane2 flow"
	@echo ""

	@echo "Run All Simulations:"
	@echo "  make all                    → Run ALL sims (no GTKWave)"
	@echo ""
	@echo "Utilities:"
	@echo "  make clean                  → Clean all builds"
	@echo "  make debug_soc              → Run structured debug TB"
	@echo ""

	@echo "===================================================="

# =========================================================
# FIRMWARE BUILD
# =========================================================
.PHONY: fw
fw:
	cd $(FW) && make && cd ..

# =========================================================
# WAVEFORM VIEW (GTKWave)
# =========================================================
.PHONY: wave
wave:
	#vcd2fst tb_top.vcd tb_top.fst
	$(GTK) tb_top.vcd &

# =========================================================
# UART
# =========================================================
uart:
	rm -rf obj_uart
	$(VERILATOR) $(VLFLAGS) \
	  --top tb_uart_top \
	  -Mdir obj_uart \
	  -o sim_uart \
	  $(RTL)/uart_tx.v \
	  $(RTL)/uart_rx.v \
	  $(RTL)/uart_top.v \
	  $(TB)/tb_uart_top.v
	./obj_uart/sim_uart
ifeq ($(OPEN_WAVE),1)
	$(GTK) tb_uart.vcd &
endif

# =========================================================
# AXI-Lite
# =========================================================
axi_uart:
	rm -rf obj_axilite
	$(VERILATOR) $(VLFLAGS) \
	  --top tb_axi_lite \
	  -Mdir obj_axilite \
	  -o sim_axilite \
	  $(RTL)/uart_tx.v \
	  $(RTL)/uart_rx.v \
	  $(RTL)/uart_axi.v \
	  $(TB)/tb_axi_lite_master.v \
	  $(TB)/tb_axi_lite.v
	./obj_axilite/sim_axilite
ifeq ($(OPEN_WAVE),1)
	$(GTK) tb_axi_lite.vcd &
endif

# Standalone AXI-Lite educational testbench (no RTL dependencies)
axi_sa:
	rm -rf obj_axi_sa
	$(VERILATOR) $(VLFLAGS) \
	  --top tb_axi_lite_standalone \
	  -Mdir obj_axi_sa \
	  -o sim_axi_sa \
	  $(TB)/tb_axi_lite_standalone.v
	./obj_axi_sa/sim_axi_sa
ifeq ($(OPEN_WAVE),1)
	$(GTK) tb_axi_lite_standalone.vcd &
endif

# =========================================================
# PicoRV32
# =========================================================
pico:
	rm -rf obj_pico
	cd $(RTL)/PicoRV32 && make clean && make firmware && cd ../..
	$(VERILATOR) $(VLFLAGS) \
	  --top tb_processor \
	  -Mdir obj_pico \
	  -o sim_pico \
	  $(RTL)/PicoRV32/picorv32.v \
	  $(RTL)/PicoRV32/Memory.v \
	  $(RTL)/PicoRV32/top.v \
	  $(RTL)/PicoRV32/tb_processor.v
	./obj_pico/sim_pico
ifeq ($(OPEN_WAVE),1)
	$(GTK) tb_picorv32.vcd &
endif

# =========================================================
# SoC
# =========================================================
soc:
	rm -rf obj_soc
	cd $(FW) && make && cd ..
	$(VERILATOR) $(VLFLAGS) \
	  --top tb_top \
	  -Mdir obj_soc \
	  -o sim_soc \
	  $(RTL)/picorv32.v \
	  $(RTL)/uart_tx.v \
	  $(RTL)/uart_rx.v \
	  $(RTL)/uart_axi.v \
	  $(RTL)/rom.v \
	  $(RTL)/sram.v \
	  $(RTL)/axi_decoder.v \
	  $(RTL)/axi_lite_interconnect.v \
	  $(RTL)/top.v \
	  $(TB)/tb_top.v
	./obj_soc/sim_soc +romhex=$(RTL)/rom.hex
ifeq ($(OPEN_WAVE),1)
	$(GTK) tb_top.vcd &
endif

# =========================================================
# SoC — PicoRV32 Memory-Mapped UART (picorv32_uart_mem sub-project)
# Delegates the full build into picorv32_uart_mem/ so that relative
# paths inside that sub-Makefile (fw/, rtl/, tb/) resolve correctly.
# =========================================================
.PHONY: soc_pico_uart_mem
SOC_MEM_DIR := $(ROOT)/picorv32_uart_mem
soc_pico_uart_mem:
	@echo "[soc_pico_uart_mem] Building firmware..."
	cd $(SOC_MEM_DIR)/fw && make
	@echo "[soc_pico_uart_mem] Compiling + simulating with Verilator..."
	rm -rf $(SOC_MEM_DIR)/obj_mem/
	$(VERILATOR) $(VLFLAGS) \
	  --top tb_mem_soc \
	  -Mdir $(SOC_MEM_DIR)/obj_mem \
	  -o sim_mem_soc \
	  $(SOC_MEM_DIR)/rtl/picorv32.v \
	  $(SOC_MEM_DIR)/rtl/uart_tx.v \
	  $(SOC_MEM_DIR)/rtl/uart_rx.v \
	  $(SOC_MEM_DIR)/rtl/mem_rom.v \
	  $(SOC_MEM_DIR)/rtl/mem_sram.v \
	  $(SOC_MEM_DIR)/rtl/uart_mem.v \
	  $(SOC_MEM_DIR)/rtl/top.v \
	  $(SOC_MEM_DIR)/tb/tb_mem_soc.v
	$(SOC_MEM_DIR)/obj_mem/sim_mem_soc +romhex=$(SOC_MEM_DIR)/rtl/rom.hex 
	@echo "[soc_pico_uart_mem] Opening waveform..."
ifeq ($(OPEN_WAVE),1)
#	vcd2fst $(ROOT)/tb_mem_soc.vcd \
	$(SOC_MEM_DIR)/tb/tb_mem_soc.fst
#	$(GTK) $(SOC_MEM_DIR)/tb/tb_mem_soc.fst &
	$(GTK) $(ROOT)/tb_mem_soc.vcd &
endif
	

# =========================================================
# RISC-V AXI-Lite Integration Demo
# Self-contained behavioral testbench — no firmware needed.
# Shows full AXI-Lite write + read handshake with formatted output.
# =========================================================
.PHONY: riscv_axi
riscv_axi:
	rm -rf obj_axi/
	$(VERILATOR) --binary -j 0 -Wall \
	  --trace \
	  --timing \
	  --top tb_riscv_axi_lite \
	  -Mdir obj_axi \
	  -o sim_axi \
	  -Wno-fatal \
	  $(TB)/tb_riscv_axi_lite.v
	./obj_axi/sim_axi
ifeq ($(OPEN_WAVE),1)
	$(GTK) tb_riscv_axi_lite.vcd &
endif

# =========================================================
# DEBUG SoC  (structured verification log – tb_debug.v)
# =========================================================
.PHONY: debug_soc
debug_soc:
	rm -rf obj_dir
	cd $(FW) && make && cd ..
	$(VERILATOR) --binary -j 0 -Wall \
	  --trace \
	  --timing \
	  --top tb_top \
	  -Mdir obj_dir \
	  -o sim_verilator \
	  -Wno-fatal \
	  -Wno-WIDTHTRUNC \
	  -Wno-WIDTHEXPAND \
	  -Wno-PROCASSWIRE \
	  -Wno-CASEINCOMPLETE \
	  -Wno-UNOPTFLAT \
	  -Wno-INITIALDLY \
	  -Wno-MULTITOP \
	  -Wno-DECLFILENAME \
	  -Wno-GENUNNAMED \
	  -Wno-UNUSEDSIGNAL \
	  -Wno-EOFNEWLINE \
	  -Wno-PINCONNECTEMPTY \
	  -Wno-BLKSEQ \
	  $(RTL)/picorv32.v \
	  $(RTL)/uart_tx.v \
	  $(RTL)/uart_rx.v \
	  $(RTL)/uart_axi.v \
	  $(RTL)/rom.v \
	  $(RTL)/sram.v \
	  $(RTL)/axi_decoder.v \
	  $(RTL)/axi_lite_interconnect.v \
	  $(RTL)/top.v \
	  $(TB)/tb_debug.v
	./obj_dir/sim_verilator +romhex=$(RTL)/rom.hex
ifeq ($(OPEN_WAVE),1)
#	vcd2fst tb_top_debug.vcd tb_top_debug.fst
	$(GTK) tb_top_debug.vcd &
endif

# =========================================================
# SYNTHESIS
# =========================================================
SHELL := /bin/bash

LIB     := openlane_design/libs/sky130_fd_sc_hd__tt_025C_1v80.lib
SRC_DIR := openlane_design/src

synth:
	
	yosys -l yosys.log -p " \
	read_verilog -D SYNTHESIS \
	$(RTL)/top.v \
	$(RTL)/picorv32.v \
	$(RTL)/uart_axi.v \
	$(RTL)/uart_tx.v \
	$(RTL)/uart_rx.v \
	$(RTL)/axi_lite_interconnect.v \
	$(RTL)/axi_decoder.v \
	$(RTL)/sram.v \
	$(RTL)/rom.v; \
	synth -top top; \
	dfflibmap -liberty $(LIB); \
	abc -liberty $(LIB); \
	opt_clean; \
	write_json top.json; \
	write_verilog synth.v; \
	stat -liberty $(LIB); \
	"


# =========================================================
# OPENLANE
# =========================================================
openlane:

	@echo "Running OpenLane..."
	openlane CMD =   ./flow.tcl -design picorv32_soc

# =========================================================
# CLEAN
# =========================================================
clean:
clean:
	@echo "[clean] Removing root obj dirs, VCD, FST..."
	rm -rf obj_* *.vcd *.fst
	@echo "[clean] Removing picorv32_uart_mem build artifacts..."
	rm -rf $(SOC_MEM_DIR)/obj_mem
	rm -f  $(SOC_MEM_DIR)/*.vcd $(SOC_MEM_DIR)/*.fst
	rm -rf $(SOC_MEM_DIR)/tb/obj_mem
	rm -f  $(SOC_MEM_DIR)/tb/*.vcd $(SOC_MEM_DIR)/tb/*.fst
	rm -f  $(ROOT)/tb_mem_soc.vcd
	@echo "[clean] Cleaning firmware..."
	cd $(FW) && make clean
	@echo "[clean] Done."
