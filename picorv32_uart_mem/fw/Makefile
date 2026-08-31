# -----------------------------------------------------------------------------
# Author       : Deepak
# Designation  : Sr. VLSI Engineer
# Organization : NIELIT CoE
# -----------------------------------------------------------------------------
# =============================================================================
# fw/Makefile – Firmware Build for PicoRV32 SoC (Memory-Mapped UART variant)
# =============================================================================
# Requires: riscv64-unknown-elf-gcc
# Produces: rom.hex  (32-bit word hex, one word per line, for $readmemh)
# =============================================================================

CROSS   ?= riscv64-unknown-elf

CC      = $(CROSS)-gcc
OBJCOPY = $(CROSS)-objcopy
OBJDUMP = $(CROSS)-objdump

# -DMEM_MAPPED documents the build variant (firmware is bit-identical)
CFLAGS  = -march=rv32i -mabi=ilp32 -O2 -Wall \
           -nostdlib -nostartfiles -ffreestanding \
           -DMEM_MAPPED

SRCS    = crt0.S main.c
LD_SCRIPT = link.ld

# ROM hex goes into the RTL directory of this variant
ROM_HEX = ../rtl/rom.hex

.PHONY: all clean disassemble

all: $(ROM_HEX)

firmware.elf: $(SRCS) $(LD_SCRIPT)
	$(CC) $(CFLAGS) -T $(LD_SCRIPT) $(SRCS) -o $@

firmware.bin: firmware.elf
	$(OBJCOPY) -O binary $< $@

$(ROM_HEX): firmware.bin
	python3 bin2hex.py firmware.bin $@
	@echo "ROM hex written to $@"

disassemble: firmware.elf
	$(OBJDUMP) -d firmware.elf

clean:
	rm -f firmware.elf firmware.bin $(ROM_HEX)
