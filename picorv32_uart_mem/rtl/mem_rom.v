/*
------------------------------------------------------------------------------
 Author       : Deepak
 Designation  : Sr. VLSI Engineer
 Organization : NIELIT CoE
------------------------------------------------------------------------------

MODULE OVERVIEW
---------------
ROM (Read-Only Memory) with PicoRV32 native memory bus interface.

This module replaces the AXI-Lite rom.v with a direct native-bus version.
No AXI bridge, no interconnect — PicoRV32 mem_valid/mem_ready handshake only.

Protocol:
  - CPU asserts mem_valid=1 with mem_addr, mem_wstrb=0 (read)
  - ROM asserts mem_ready=1 with mem_rdata in next cycle
  - Transaction complete when both mem_valid & mem_ready are high

ASIC-clean:
  - No inline reg initializers
  - $readmemh only under `ifndef SYNTHESIS
  - synthesizable case path under `ifdef SYNTHESIS
  - No initial blocks in synthesis path
*/

`timescale 1ns / 1ps

module mem_rom #(
    parameter MEM_DEPTH = 2048,         // Number of 32-bit words (8 KB)
    parameter INIT_FILE = "rom.hex"
)(
    input              clk,
    input              reset,

    // PicoRV32 native memory bus (read-only slave)
    input              mem_valid,       // CPU has a valid request
    output reg         mem_ready,       // ROM response ready
    input       [31:0] mem_addr,        // Byte address from CPU
    output reg  [31:0] mem_rdata        // Read data to CPU
);

`ifdef SYNTHESIS
    // -----------------------------------------------------------------------
    // SYNTHESIS PATH: synthesizable ROM via case statement
    // Generated from rom.hex by fw/gen_rom_case.py
    // Yosys infers this as a read-only LUT/memory.
    // -----------------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mem_rdata <= 32'h00000013;  // NOP
            mem_ready <= 1'b0;
        end else begin
            mem_ready <= 1'b0;

            if (mem_valid && !mem_ready) begin
                mem_ready <= 1'b1;
                case (mem_addr[$clog2(MEM_DEPTH)+1 : 2])
                    11'd0: mem_rdata <= 32'h00020137;
                    11'd1: mem_rdata <= 32'hFFC10113;
                    11'd2: mem_rdata <= 32'h00010297;
                    11'd3: mem_rdata <= 32'hFF828293;
                    11'd4: mem_rdata <= 32'h00010317;
                    11'd5: mem_rdata <= 32'hFF030313;
                    11'd6: mem_rdata <= 32'h0062D863;
                    11'd7: mem_rdata <= 32'h0002A023;
                    11'd8: mem_rdata <= 32'h00428293;
                    11'd9: mem_rdata <= 32'hFF5FF06F;
                    11'd10: mem_rdata <= 32'h0E0000EF;
                    11'd11: mem_rdata <= 32'h0000006F;
                    11'd12: mem_rdata <= 32'h00054683;
                    11'd13: mem_rdata <= 32'h02068663;
                    11'd14: mem_rdata <= 32'h10000737;
                    11'd15: mem_rdata <= 32'h10000637;
                    11'd16: mem_rdata <= 32'h00870713;
                    11'd17: mem_rdata <= 32'h00150513;
                    11'd18: mem_rdata <= 32'h00072783;
                    11'd19: mem_rdata <= 32'h0017F793;
                    11'd20: mem_rdata <= 32'hFE078CE3;
                    11'd21: mem_rdata <= 32'h00D62023;
                    11'd22: mem_rdata <= 32'h00054683;
                    11'd23: mem_rdata <= 32'hFE0694E3;
                    11'd24: mem_rdata <= 32'h00008067;
                    11'd25: mem_rdata <= 32'h10000737;
                    11'd26: mem_rdata <= 32'h00455693;
                    11'd27: mem_rdata <= 32'h00870713;
                    11'd28: mem_rdata <= 32'h00F57513;
                    11'd29: mem_rdata <= 32'h00072783;
                    11'd30: mem_rdata <= 32'h0017F793;
                    11'd31: mem_rdata <= 32'hFE078CE3;
                    11'd32: mem_rdata <= 32'h10000737;
                    11'd33: mem_rdata <= 32'h100007B7;
                    11'd34: mem_rdata <= 32'h03000613;
                    11'd35: mem_rdata <= 32'h00C7A023;
                    11'd36: mem_rdata <= 32'h00870713;
                    11'd37: mem_rdata <= 32'h00072783;
                    11'd38: mem_rdata <= 32'h0017F793;
                    11'd39: mem_rdata <= 32'hFE078CE3;
                    11'd40: mem_rdata <= 32'h100007B7;
                    11'd41: mem_rdata <= 32'h07800713;
                    11'd42: mem_rdata <= 32'h00E7A023;
                    11'd43: mem_rdata <= 32'h00900793;
                    11'd44: mem_rdata <= 32'h03768613;
                    11'd45: mem_rdata <= 32'h00D7E463;
                    11'd46: mem_rdata <= 32'h03068613;
                    11'd47: mem_rdata <= 32'h10000737;
                    11'd48: mem_rdata <= 32'h00870713;
                    11'd49: mem_rdata <= 32'h00072783;
                    11'd50: mem_rdata <= 32'h0017F793;
                    11'd51: mem_rdata <= 32'hFE078CE3;
                    11'd52: mem_rdata <= 32'h100007B7;
                    11'd53: mem_rdata <= 32'h00C7A023;
                    11'd54: mem_rdata <= 32'h00900793;
                    11'd55: mem_rdata <= 32'h03750693;
                    11'd56: mem_rdata <= 32'h00A7E463;
                    11'd57: mem_rdata <= 32'h03050693;
                    11'd58: mem_rdata <= 32'h10000737;
                    11'd59: mem_rdata <= 32'h00870713;
                    11'd60: mem_rdata <= 32'h00072783;
                    11'd61: mem_rdata <= 32'h0017F793;
                    11'd62: mem_rdata <= 32'hFE078CE3;
                    11'd63: mem_rdata <= 32'h100007B7;
                    11'd64: mem_rdata <= 32'h00D7A023;
                    11'd65: mem_rdata <= 32'h00008067;
                    11'd66: mem_rdata <= 32'hFC010113;
                    11'd67: mem_rdata <= 32'h36C00513;
                    11'd68: mem_rdata <= 32'h02112E23;
                    11'd69: mem_rdata <= 32'h02812C23;
                    11'd70: mem_rdata <= 32'h02912A23;
                    11'd71: mem_rdata <= 32'h03212823;
                    11'd72: mem_rdata <= 32'h03312623;
                    11'd73: mem_rdata <= 32'h03412423;
                    11'd74: mem_rdata <= 32'h03512223;
                    11'd75: mem_rdata <= 32'h03612023;
                    11'd76: mem_rdata <= 32'h01712E23;
                    11'd77: mem_rdata <= 32'h01812C23;
                    11'd78: mem_rdata <= 32'hEF9FF0EF;
                    11'd79: mem_rdata <= 32'h38000513;
                    11'd80: mem_rdata <= 32'hEF1FF0EF;
                    11'd81: mem_rdata <= 32'h38400513;
                    11'd82: mem_rdata <= 32'hEE9FF0EF;
                    11'd83: mem_rdata <= 32'h04800513;
                    11'd84: mem_rdata <= 32'hF15FF0EF;
                    11'd85: mem_rdata <= 32'h38C00513;
                    11'd86: mem_rdata <= 32'hED9FF0EF;
                    11'd87: mem_rdata <= 32'h38400513;
                    11'd88: mem_rdata <= 32'hED1FF0EF;
                    11'd89: mem_rdata <= 32'h06900513;
                    11'd90: mem_rdata <= 32'hEFDFF0EF;
                    11'd91: mem_rdata <= 32'h39400513;
                    11'd92: mem_rdata <= 32'hEC1FF0EF;
                    11'd93: mem_rdata <= 32'h38000513;
                    11'd94: mem_rdata <= 32'hEB9FF0EF;
                    11'd95: mem_rdata <= 32'h10000737;
                    11'd96: mem_rdata <= 32'h00870713;
                    11'd97: mem_rdata <= 32'h00072783;
                    11'd98: mem_rdata <= 32'h0027F793;
                    11'd99: mem_rdata <= 32'hFE078CE3;
                    11'd100: mem_rdata <= 32'h100007B7;
                    11'd101: mem_rdata <= 32'h0047A683;
                    11'd102: mem_rdata <= 32'h10000737;
                    11'd103: mem_rdata <= 32'h00870713;
                    11'd104: mem_rdata <= 32'h00D10623;
                    11'd105: mem_rdata <= 32'h00072783;
                    11'd106: mem_rdata <= 32'h0027F793;
                    11'd107: mem_rdata <= 32'hFE078CE3;
                    11'd108: mem_rdata <= 32'h100007B7;
                    11'd109: mem_rdata <= 32'h0047A603;
                    11'd110: mem_rdata <= 32'h10000737;
                    11'd111: mem_rdata <= 32'h00870713;
                    11'd112: mem_rdata <= 32'h00C106A3;
                    11'd113: mem_rdata <= 32'h00072783;
                    11'd114: mem_rdata <= 32'h0027F793;
                    11'd115: mem_rdata <= 32'hFE078CE3;
                    11'd116: mem_rdata <= 32'h100007B7;
                    11'd117: mem_rdata <= 32'h0047A603;
                    11'd118: mem_rdata <= 32'h10000737;
                    11'd119: mem_rdata <= 32'h00870713;
                    11'd120: mem_rdata <= 32'h00C10723;
                    11'd121: mem_rdata <= 32'h00072783;
                    11'd122: mem_rdata <= 32'h0027F793;
                    11'd123: mem_rdata <= 32'hFE078CE3;
                    11'd124: mem_rdata <= 32'h100007B7;
                    11'd125: mem_rdata <= 32'h0047A603;
                    11'd126: mem_rdata <= 32'h10000737;
                    11'd127: mem_rdata <= 32'h00870713;
                    11'd128: mem_rdata <= 32'h00C107A3;
                    11'd129: mem_rdata <= 32'h00072783;
                    11'd130: mem_rdata <= 32'h0017F793;
                    11'd131: mem_rdata <= 32'hFE078CE3;
                    11'd132: mem_rdata <= 32'h0FF6F693;
                    11'd133: mem_rdata <= 32'h100007B7;
                    11'd134: mem_rdata <= 32'h00D7A023;
                    11'd135: mem_rdata <= 32'h00D14683;
                    11'd136: mem_rdata <= 32'h10000737;
                    11'd137: mem_rdata <= 32'h00870713;
                    11'd138: mem_rdata <= 32'h00072783;
                    11'd139: mem_rdata <= 32'h0017F793;
                    11'd140: mem_rdata <= 32'hFE078CE3;
                    11'd141: mem_rdata <= 32'h100007B7;
                    11'd142: mem_rdata <= 32'h00D7A023;
                    11'd143: mem_rdata <= 32'h00E14683;
                    11'd144: mem_rdata <= 32'h10000737;
                    11'd145: mem_rdata <= 32'h00870713;
                    11'd146: mem_rdata <= 32'h00072783;
                    11'd147: mem_rdata <= 32'h0017F793;
                    11'd148: mem_rdata <= 32'hFE078CE3;
                    11'd149: mem_rdata <= 32'h100007B7;
                    11'd150: mem_rdata <= 32'h00D7A023;
                    11'd151: mem_rdata <= 32'h00F14683;
                    11'd152: mem_rdata <= 32'h10000737;
                    11'd153: mem_rdata <= 32'h00870713;
                    11'd154: mem_rdata <= 32'h00072783;
                    11'd155: mem_rdata <= 32'h0017F793;
                    11'd156: mem_rdata <= 32'hFE078CE3;
                    11'd157: mem_rdata <= 32'h10000437;
                    11'd158: mem_rdata <= 32'h100007B7;
                    11'd159: mem_rdata <= 32'h00D7A023;
                    11'd160: mem_rdata <= 32'h00C10B93;
                    11'd161: mem_rdata <= 32'h01010A93;
                    11'd162: mem_rdata <= 32'h35C00993;
                    11'd163: mem_rdata <= 32'h36000913;
                    11'd164: mem_rdata <= 32'h35400493;
                    11'd165: mem_rdata <= 32'h10000B37;
                    11'd166: mem_rdata <= 32'h00840413;
                    11'd167: mem_rdata <= 32'h00A00A13;
                    11'd168: mem_rdata <= 32'h05200693;
                    11'd169: mem_rdata <= 32'h00048713;
                    11'd170: mem_rdata <= 32'h00170713;
                    11'd171: mem_rdata <= 32'h00042783;
                    11'd172: mem_rdata <= 32'h0017F793;
                    11'd173: mem_rdata <= 32'hFE078CE3;
                    11'd174: mem_rdata <= 32'h00DB2023;
                    11'd175: mem_rdata <= 32'h00074683;
                    11'd176: mem_rdata <= 32'hFE0694E3;
                    11'd177: mem_rdata <= 32'h000BCC03;
                    11'd178: mem_rdata <= 32'h000C0513;
                    11'd179: mem_rdata <= 32'hD99FF0EF;
                    11'd180: mem_rdata <= 32'h02000693;
                    11'd181: mem_rdata <= 32'h00098713;
                    11'd182: mem_rdata <= 32'h00170713;
                    11'd183: mem_rdata <= 32'h00042783;
                    11'd184: mem_rdata <= 32'h0017F793;
                    11'd185: mem_rdata <= 32'hFE078CE3;
                    11'd186: mem_rdata <= 32'h00DB2023;
                    11'd187: mem_rdata <= 32'h00074683;
                    11'd188: mem_rdata <= 32'hFE0694E3;
                    11'd189: mem_rdata <= 32'h00042783;
                    11'd190: mem_rdata <= 32'h0017F793;
                    11'd191: mem_rdata <= 32'hFE078CE3;
                    11'd192: mem_rdata <= 32'h018B2023;
                    11'd193: mem_rdata <= 32'h02700693;
                    11'd194: mem_rdata <= 32'h00090713;
                    11'd195: mem_rdata <= 32'h00170713;
                    11'd196: mem_rdata <= 32'h00042783;
                    11'd197: mem_rdata <= 32'h0017F793;
                    11'd198: mem_rdata <= 32'hFE078CE3;
                    11'd199: mem_rdata <= 32'h00DB2023;
                    11'd200: mem_rdata <= 32'h00074683;
                    11'd201: mem_rdata <= 32'hFE0694E3;
                    11'd202: mem_rdata <= 32'h000BC503;
                    11'd203: mem_rdata <= 32'hD39FF0EF;
                    11'd204: mem_rdata <= 32'h00042783;
                    11'd205: mem_rdata <= 32'h0017F793;
                    11'd206: mem_rdata <= 32'hFE078CE3;
                    11'd207: mem_rdata <= 32'h014B2023;
                    11'd208: mem_rdata <= 32'h001B8B93;
                    11'd209: mem_rdata <= 32'hF57A9EE3;
                    11'd210: mem_rdata <= 32'h39C00513;
                    11'd211: mem_rdata <= 32'hCE5FF0EF;
                    11'd212: mem_rdata <= 32'h0000006F;
                    11'd213: mem_rdata <= 32'h203A5852;
                    11'd214: mem_rdata <= 32'h00000000;
                    11'd215: mem_rdata <= 32'h00272820;
                    11'd216: mem_rdata <= 32'h2D202927;
                    11'd217: mem_rdata <= 32'h5854203E;
                    11'd218: mem_rdata <= 32'h0000203A;
                    11'd219: mem_rdata <= 32'h54524155;
                    11'd220: mem_rdata <= 32'h622D3820;
                    11'd221: mem_rdata <= 32'h44207469;
                    11'd222: mem_rdata <= 32'h0A6F6D65;
                    11'd223: mem_rdata <= 32'h00000000;
                    11'd224: mem_rdata <= 32'h0000000A;
                    11'd225: mem_rdata <= 32'h203A5854;
                    11'd226: mem_rdata <= 32'h00000000;
                    11'd227: mem_rdata <= 32'h48272820;
                    11'd228: mem_rdata <= 32'h000A2927;
                    11'd229: mem_rdata <= 32'h69272820;
                    11'd230: mem_rdata <= 32'h000A2927;
                    11'd231: mem_rdata <= 32'h5341500A;
                    11'd232: mem_rdata <= 32'h00000A53;
                    default: mem_rdata <= 32'h00000013; // NOP
                endcase
            end
        end
    end

`else
    // -----------------------------------------------------------------------
    // SIMULATION PATH: load from hex file via $readmemh
    // -----------------------------------------------------------------------
    reg [31:0] mem [0:MEM_DEPTH-1];
    integer ii;

    initial begin : rom_init
        reg [1023:0] rom_path;

        // Fill with NOPs first
        for (ii = 0; ii < MEM_DEPTH; ii = ii + 1)
            mem[ii] = 32'h00000013;

        // Override via plusarg, then parameter
        if ($value$plusargs("romhex=%s", rom_path)) begin
            $readmemh(rom_path, mem);
            $display("[MEM_ROM] loaded from plusarg: %0s", rom_path);
        end else if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
            $display("[MEM_ROM] loaded from parameter: %s", INIT_FILE);
        end else begin
            $display("[MEM_ROM] WARNING: ROM contains NOPs only");
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mem_ready <= 1'b0;
            mem_rdata <= 32'h00000013;
        end else begin
            mem_ready <= 1'b0;

            if (mem_valid && !mem_ready) begin
                mem_rdata <= mem[mem_addr[$clog2(MEM_DEPTH)+1 : 2]];
                mem_ready <= 1'b1;
            end
        end
    end
`endif

endmodule
