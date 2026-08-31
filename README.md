# PicoRV32 AXI-Lite UART SoC

A complete RISC-V based System-on-Chip (SoC) subsystem built around the **PicoRV32** processor core, with an **AXI4-Lite interconnect**, **memory-mapped UART peripheral**, ROM, SRAM, bare-metal firmware, RTL testbenches, and an ASIC-oriented implementation flow.

This project was developed as part of an SoC/VLSI learning and implementation workflow covering RISC-V, AXI4-Lite, UART, memory-mapped I/O, firmware, RTL simulation, synthesis, and physical-design preparation.

---

## Project Overview

The goal of this project is to integrate a small RISC-V processor with memory and peripherals to form a functional SoC subsystem.

The main processing element is the **PicoRV32 RISC-V CPU**. The processor communicates with the rest of the system through an **AXI4-Lite master interface**.

The AXI4-Lite interface is connected to memory-mapped peripherals through an interconnect and address decoder.

The system includes:

- PicoRV32 RISC-V processor
- AXI4-Lite master interface
- AXI-Lite interconnect
- AXI address decoder
- UART peripheral with AXI-Lite interface
- UART transmitter and receiver
- ROM for firmware storage
- SRAM for data storage
- Bare-metal RISC-V firmware
- RTL simulation testbenches
- Yosys synthesis-related files
- OpenLane-oriented physical design files
- Sky130 standard-cell library configuration
- Timing and pin constraint files

---

## System Architecture

The high-level architecture of the SoC is:

```text
                    +----------------------+
                    |      PicoRV32        |
                    |     RISC-V CPU       |
                    +----------+-----------+
                               |
                               | AXI4-Lite
                               v
                    +----------------------+
                    |   AXI-Lite           |
                    |   Interconnect       |
                    +----------+-----------+
                               |
                    +----------+-----------+
                    |                      |
                    v                      v
             +-------------+        +-------------+
             | AXI Decoder |        |    UART     |
             |             |        | AXI-Lite    |
             +------+------+        +------+------+
                    |                      |
                    v                      v
             +-------------+        +-------------+
             | ROM / SRAM  |        | UART TX/RX  |
             +-------------+        +-------------+

The CPU executes firmware stored in memory. When software accesses a peripheral address, the AXI-Lite interconnect and decoder route the transaction to the appropriate hardware block.

Main Components
1. PicoRV32 RISC-V Processor

PicoRV32 is a small RISC-V processor core implemented in Verilog.

The project contains PicoRV32 sources and an AXI-Lite based integration.

The processor is responsible for:

Fetching instructions
Executing RISC-V instructions
Performing memory accesses
Generating AXI-Lite transactions
Accessing memory-mapped peripherals
2. AXI4-Lite Interconnect

The AXI-Lite interconnect provides communication between the processor and the different slaves in the SoC.

The main AXI-Lite channels involved are:

Write Address
Write Data
Write Response
Read Address
Read Data

The interconnect uses address information to determine which peripheral should receive a transaction.

Relevant RTL files include:

rtl/axi_lite_interconnect.v
rtl/axi_decoder.v
3. UART Peripheral

The UART is implemented as a memory-mapped AXI-Lite peripheral.

The UART subsystem contains:

uart_axi.v
uart_rx.v
uart_tx.v

The processor can access the UART through memory-mapped addresses rather than directly controlling UART signals.

This allows software running on the RISC-V processor to communicate with the UART hardware.

4. ROM and SRAM

The SoC contains memory components for instruction and data storage.

Relevant RTL sources include:

rtl/rom.v
rtl/sram.v

A firmware image is converted into a hexadecimal memory representation and loaded into the ROM used by the RTL design.

Firmware

The project also contains bare-metal firmware written in C and RISC-V assembly.

The firmware directory contains:

fw/
├── main.c
├── crt0.S
├── link.ld
├── Makefile
├── bin2hex.py
└── gen_rom_case.py
Firmware flow
        main.c
          |
          v
   RISC-V Compiler
          |
          v
      firmware ELF
          |
          v
      firmware BIN
          |
          v
       rom.hex
          |
          v
       ROM / RTL

The firmware is intended to execute directly on the PicoRV32 processor without an operating system.

RTL Structure

The main RTL directories include:

rtl/
├── PicoRV32/
├── axi_decoder.v
├── axi_lite_interconnect.v
├── picorv32.v
├── rom.v
├── sram.v
├── top.v
├── uart_axi.v
├── uart_rx.v
└── uart_tx.v

The top.v module provides the top-level integration of the SoC components.

Simulation and Verification

The repository contains several RTL testbenches under:

tb/

Examples include:

tb_axi_lite.cpp
tb_axi_lite.v
tb_axi_lite_master.v
tb_axi_lite_standalone.v
tb_axi_lite_wrap.v
tb_riscv_axi_lite.v
tb_top.cpp
tb_top.v
tb_uart_top.cpp
tb_uart_top.v

These testbenches are intended to exercise different parts of the SoC, including:

AXI-Lite transactions
AXI-Lite master behavior
RISC-V to AXI-Lite communication
Top-level SoC behavior
UART functionality

The repository also contains waveform/testbench-related material for analyzing RTL behavior.

Synthesis

The project contains RTL and synthesis-related files for logic synthesis using Yosys.

Important files include:

synth.v
top.json
yosys.log
src/

The synthesis flow converts the RTL description into a synthesized representation suitable for further implementation.

ASIC / OpenLane Preparation

The project also contains an openlane_design/ directory containing files for an ASIC implementation flow.

openlane_design/
├── config.json
├── pin_order.cfg
├── top.sdc
├── src/
├── libs/
└── vsrc/

The design is configured around the SkyWater SKY130 technology ecosystem.

The repository therefore covers a flow extending beyond RTL design:

RTL
 |
 v
Simulation
 |
 v
Synthesis
 |
 v
ASIC Physical Design Preparation
Project Directory Structure
picorv32_soc_new/
│
├── fw/                         # RISC-V bare-metal firmware
│
├── rtl/                        # Main RTL sources
│   ├── PicoRV32/
│   ├── axi_decoder.v
│   ├── axi_lite_interconnect.v
│   ├── picorv32.v
│   ├── rom.v
│   ├── sram.v
│   ├── top.v
│   ├── uart_axi.v
│   ├── uart_rx.v
│   └── uart_tx.v
│
├── tb/                         # RTL testbenches
│
├── src/                        # Synthesis-related sources
│
├── openlane_design/            # ASIC/OpenLane design files
│
├── picorv32_uart_mem/          # Memory-mapped UART SoC implementation
│
├── libs/                       # Standard-cell library files
│
├── vsrc/                       # Additional implementation files
│
├── Makefile                    # Project build commands
├── config.json                 # Project configuration
├── pin_order.cfg               # Pin ordering
├── top.sdc                     # Timing constraints
├── synth.v                     # Synthesized design
└── yosys.log                   # Yosys synthesis log
Learning Modules

The repository also includes documentation covering the major concepts used in the project.

The project documentation is organized into modules covering:

RISC-V ISA fundamentals
Introduction to AXI4-Lite
UART protocol
Memory-mapped interface between RISC-V and UART
RISC-V and AXI-Lite integration
AXI-Lite and UART integration
Firmware implementation
Full SoC subsystem integration
Waveform analysis using testbenches

These modules provide a progressive path from individual concepts to the complete SoC.

Technologies Used
Area	Technology
Processor	PicoRV32
ISA	RISC-V
Bus	AXI4-Lite
HDL	Verilog
Firmware	C / RISC-V Assembly
Simulation	RTL testbenches
Synthesis	Yosys
Physical Design	OpenLane-oriented flow
Technology	SkyWater SKY130
Build System	Make
Key Concepts Demonstrated

This project brings together several important digital design and VLSI concepts:

RISC-V processor integration
RV32 instruction execution
AXI4-Lite protocol
Memory-mapped I/O
Address decoding
SoC interconnect design
UART communication
ROM and SRAM integration
Bare-metal firmware
RTL testbench development
RTL-to-netlist synthesis
Timing constraints
ASIC physical-design preparation
Getting Started

Clone the repository and enter the project directory.

git clone <repository-url>
cd picorv32-axi-lite-uart-soc

The main build and simulation commands are documented in the project Makefile and supporting project documentation.

A typical workflow is:

1. Build firmware
       |
       v
2. Generate ROM image
       |
       v
3. Compile RTL
       |
       v
4. Run simulation
       |
       v
5. Analyze waveform
       |
       v
6. Run synthesis
       |
       v
7. Continue to ASIC implementation flow
Project Status

The repository contains the complete project source tree supplied for the SoC implementation workflow, including RTL, firmware, testbenches, synthesis files, and ASIC implementation files.

Simulation and implementation results are being evaluated as part of the project workflow.

Future Work

Possible extensions include:

Complete RTL simulation and waveform verification
Detailed AXI-Lite protocol verification
UART functional verification
Firmware/RTL co-simulation
Timing analysis
Area and power analysis
OpenLane physical implementation
Static timing analysis
Layout generation
Further optimization of the SoC architecture
Acknowledgements

This project uses the PicoRV32 RISC-V processor core and builds an SoC integration around it.

The project also uses open-source RTL design and ASIC implementation tools and methodologies.

Author

Triparnocodes

VLSI / Digital Design / RISC-V / SoC Design

Note

This repository is primarily intended as a learning and implementation project demonstrating the integration of a RISC-V processor, AXI4-Lite interconnect, memory-mapped UART, firmware, simulation, synthesis, and ASIC-oriented design flow.
