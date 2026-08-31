# ============================================================
#  Makefile  -  PicoRV32 Simulation (with Firmware Build)
#
#  DEFAULT target: Verilator
#
#  Flow:
#    code.S → (Python script) → fw/code.hex → copy → code.hex
#    → Verilator simulation
#
#  Targets:
#    make / make verilator  - build firmware + run Verilator
#    make firmware          - only build firmware
#    make icarus            - simulate with Icarus Verilog
#    make wave              - open Verilator VCD
#    make wave_icarus       - open Icarus VCD
#    make clean             - clean build files
# ============================================================

# ==============================================================
#  RTL + TB Files
# ==============================================================
RTL_FILES  = top.v Memory.v picorv32.v
TB_VERILOG = tb_processor.v
TB_CPP     = tb_processor.cpp

TOP_MODULE = tb_processor
DUT_MODULE = top

# ==============================================================
#  Firmware Build (Python-based)
# ==============================================================
FW_SCRIPT = fw/hex.py
FW_INPUT  = fw/code.S
FW_OUTPUT = code.hex

.PHONY: firmware
firmware:
	@echo "=== [FW] Building firmware from $(FW_INPUT) ==="
	cd fw && python3 hex.py && cd ..
	@echo "=== [FW] Generated $(FW_OUTPUT) ==="

# ==============================================================
#  Verilator (PRIMARY)
# ==============================================================
VERILATOR     = verilator
VERILATOR_DIR = obj_dir
VCD_VLT       = tb_processor_verilator.vcd
SIM_EXE       = $(VERILATOR_DIR)/V$(DUT_MODULE)

VERILATOR_FLAGS = \
	--cc \
	--exe \
	--build \
	--trace \
	--public \
	-Wno-fatal \
	-Wno-WIDTHEXPAND \
	-Wno-WIDTHTRUNC \
	-Wno-PINMISSING \
	-Wno-CASEOVERLAP \
	-Wno-CASEINCOMPLETE \
	-Wno-BLKSEQ \
	--top-module $(DUT_MODULE)

.PHONY: all
all: verilator

.PHONY: verilator
verilator: firmware
	@echo "=== [1/2] Compiling with Verilator ==="
	$(VERILATOR) $(VERILATOR_FLAGS) $(RTL_FILES) $(TB_CPP)
	@echo "=== [2/2] Running simulation ==="
	$(SIM_EXE)
	@echo "=== Done. VCD: $(VCD_VLT) ==="

# ==============================================================
#  Icarus Verilog (secondary)
# ==============================================================
IVERILOG   = iverilog
VVP        = vvp
VCD_ICARUS = tb_processor.vcd
SIM_BIN    = sim_out

.PHONY: icarus
icarus: firmware $(SIM_BIN)
	@echo "=== Running Icarus simulation ==="
	$(VVP) $(SIM_BIN)

$(SIM_BIN): $(TB_VERILOG) $(RTL_FILES)
	$(IVERILOG) -o $@ -s $(TOP_MODULE) $(TB_VERILOG) $(RTL_FILES)

# ==============================================================
#  GTKWave
# ==============================================================
.PHONY: wave
wave:
	gtkwave $(VCD_VLT) &

.PHONY: wave_icarus
wave_icarus:
	gtkwave $(VCD_ICARUS) &

# ==============================================================
#  Clean
# ==============================================================
.PHONY: clean
clean:
	rm -rf $(VERILATOR_DIR) $(SIM_BIN) *.vcd *.gtkw
	rm -rf fw/*.o fw/*.elf fw/*.bin fw/*.dump fw/*_raw.hex fw/*.hex
	rm -f code.hex
	@echo "=== Cleaned all build artifacts ==="