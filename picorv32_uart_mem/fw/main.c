/*
 * ============================================================================
 *  main.c — PicoRV32 Memory-Mapped UART | Sub-module 4 Demo
 *  Author : Deepak | Sr. VLSI Engineer | NIELIT CoE
 * ============================================================================
 *
 *  LEARNING OBJECTIVES
 *  ────────────────────
 *  1. Memory-mapped I/O  : peripherals live at fixed addresses
 *  2. volatile keyword   : must re-read hardware registers every access
 *  3. Status polling     : check TX_READY before send, RX_VALID before receive
 *  4. Bit masking        : isolate individual status bits with & operator
 *
 *  UART REGISTER MAP  (base = 0x1000_0000)
 *  ─────────────────────────────────────────
 *   Offset  Name        Access   Description
 *   +0x0    UART_TX     Write    Byte to transmit (UART sends it as 8N1)
 *   +0x4    UART_RX     Read     Last received byte (clear-on-read)
 *   +0x8    UART_STATUS Read     [0]=tx_ready  [1]=rx_valid
 *
 *  EXPECTED SIMULATION OUTPUT
 *  ──────────────────────────
 *   Hello Deepak from Nielit!   (repeated 10 times)
 *   <echo loop: PING → echoed back byte-by-byte>
 * ============================================================================
 */

/* ─── Step 1: Define hardware registers ──────────────────────────────────────
 *
 *  REG(addr) casts an integer address to a volatile 32-bit pointer.
 *  'volatile' tells the compiler: NEVER cache this value — always go to HW.
 */
#define REG(addr)     (*(volatile unsigned int *)(addr))

#define UART_TX       REG(0x10000000UL)
#define UART_RX       REG(0x10000004UL)
#define UART_STATUS   REG(0x10000008UL)

#define TX_READY      (1u << 0)   /* Bit 0: transmitter idle, safe to write */
#define RX_VALID      (1u << 1)   /* Bit 1: received byte waiting in UART_RX */


/* ─── Step 2: UART driver ─────────────────────────────────────────────────────
 *
 *  These 3 functions are the complete UART library for bare-metal firmware.
 *  No printf, no libc, no OS — just load/store to hardware registers.
 */

/* Send one character — wait for TX ready, then write */
static void uart_putc(char c)
{
    while (!(UART_STATUS & TX_READY))   /* poll bit 0 */
        ;
    UART_TX = (unsigned int)(unsigned char)c;
}

/* Send a null-terminated string */
static void uart_puts(const char *s)
{
    while (*s)
        uart_putc(*s++);
}

/* Receive one character — block until RX byte arrives */
static char uart_getc(void)
{
    while (!(UART_STATUS & RX_VALID))   /* poll bit 1 */
        ;
    return (char)(UART_RX & 0xFF);      /* clear-on-read in hardware */
}


/* ─── Step 3: Main program ────────────────────────────────────────────────────
 *
 *  Phase A: Print greeting "Hello Deepak from Nielit!\n" 10 times
 *  Phase B: Infinite echo loop — every received byte is immediately echoed back
 */
int main(void)
{
    int i;

    /* ── Phase A: 10 greeting messages ─────────────────────────────────────── */
    for (i = 0; i < 10; i++)
        uart_puts("Hello Deepak from Nielit!\n");

    /* ── Phase B: Infinite echo loop ────────────────────────────────────────── *
     *                                                                           *
     *  Firmware waits for a byte on RX, then immediately echoes it on TX.      *
     *  Testbench sends "PING" (4 bytes) and verifies the echo.                 *
     *  This loop never exits — simulation is ended by testbench $finish.       */
    while (1)
        uart_putc(uart_getc());

    return 0;
}

