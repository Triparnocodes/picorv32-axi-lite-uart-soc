# -----------------------------------------------------------------------------
# Author       : Deepak
# Designation  : Sr. VLSI Engineer
# Organization : NIELIT CoE
# -----------------------------------------------------------------------------
# =============================================================================
# fw/Makefile – Firmware Build for PicoRV32 SoC
# =============================================================================
# Requires: riscv32-unknown-elf-gcc (or riscv64-unknown-elf-gcc with -march=rv32i)
# Produces: rom.hex   – 32-bit word hex file, one word per line, loaded by ROM
# =============================================================================

# Adjust this if your toolchain prefix differs
CROSS   ?= riscv64-unknown-elf

CC      = $(CROSS)-gcc
OBJCOPY = $(CROSS)-objcopy
OBJDUMP = $(CROSS)-objdump

CFLAGS  = -march=rv32i -mabi=ilp32 -O2 -Wall \
           -nostdlib -nostartfiles -ffreestanding

SRCS    = crt0.S main.c
LD_SCRIPT = link.ld

# Output ROM hex goes one level up into rtl/ so ROM module finds it
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
	$(OBJDUMP) -d firmware.elf | less

clean:
	rm -f firmware.elf firmware.bin $(ROM_HEX)
