module top (
    input clk,
    input reset_n,
    output mem_valid,
    output mem_instr,
    output mem_ready,
    output [31:0] mem_addr,
    output [31:0] mem_wdata,
    output [3:0] mem_wstrb,
    output [31:0] mem_rdata,
    output trap
);

// Define internal wires
assign mem_ready = 1'b1;

// Memory instantiation
Memory #(
    .MEM_FILE("rtl/PicoRV32/code.hex"),
    .SIZE(1024)
) D_mem_unit (
    .clk(clk),
    .mem_addr(mem_addr),
    .mem_rdata(mem_rdata),
    .mem_rstrb(mem_valid & !(|mem_wstrb)),
    .mem_wdata(mem_wdata),
    .mem_wmask(mem_wstrb)
);

// Processor instantiation
picorv32 #() processor (
    .clk      (clk),
    .resetn   (reset_n),
    .trap     (trap),
    .mem_valid(mem_valid),
    .mem_instr(mem_instr),
    .mem_ready(mem_ready),
    .mem_addr (mem_addr),
    .mem_wdata(mem_wdata),
    .mem_wstrb(mem_wstrb),
    .mem_rdata(mem_rdata)
);

endmodule
