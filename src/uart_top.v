//
// UART Top Module
// Variable-clock UART with parameterized FIFOs and MMIO interface
//
`timescale 1ns/1ps

module uart_top #(
    parameter CLK_FREQ_HZ = 50_000_000, // Default 50MHz clock
    parameter DEFAULT_BAUD = 115200,    // Default baud rate
    parameter TX_FIFO_DEPTH = 16,       // TX buffer depth
    parameter RX_FIFO_DEPTH = 16,       // RX buffer depth
    parameter DATA_BITS = 8,            // Always 8 for 8N1
    parameter STOP_BITS = 1,            // Always 1 for 8N1
    parameter PARITY = "NONE",          // Always NONE for 8N1
    parameter OVERSAMPLE = 16           // Oversampling factor
) (
    // Clock and reset
    input wire clk,
    input wire rst_n,
    
    // Serial interface
    input wire rx,
    output wire tx,
    
    // MMIO interface
    input wire [3:0] addr,        // Register address
    input wire [31:0] wdata,      // Write data
    output reg [31:0] rdata,      // Read data
    input wire wr_en,             // Write enable
    input wire rd_en,             // Read enable
    
    // Interrupt signals
    output wire tx_empty_irq,     // TX FIFO empty interrupt
    output wire rx_ready_irq,     // RX data ready interrupt
    output wire rx_overrun_irq    // RX overrun error interrupt
);

    // Internal signals
    wire tx_fifo_write;
    wire tx_fifo_read;
    wire tx_fifo_empty;
    wire tx_fifo_full;
    wire [DATA_BITS-1:0] tx_fifo_data_out;
    wire tx_busy;
    
    wire rx_fifo_write;
    wire rx_fifo_read;
    wire rx_fifo_empty;
    wire rx_fifo_full;
    wire [DATA_BITS-1:0] rx_fifo_data_in;
    wire [DATA_BITS-1:0] rx_fifo_data_out;
    wire rx_data_ready;
    wire rx_frame_error;
    wire rx_overrun;
    
    wire [15:0] baud_div;
    wire uart_en;
    wire tx_fifo_reset;
    wire rx_fifo_reset;
    wire loopback_en;
    wire [7:0] tx_fifo_threshold;
    wire [7:0] rx_fifo_threshold;
    
    wire tx_fifo_threshold_reached;
    wire rx_fifo_threshold_reached;
    
    // Instantiate register block
    uart_regs #(
        .DATA_BITS(DATA_BITS)
    ) regs (
        .clk(clk),
        .rst_n(rst_n),
        .addr(addr),
        .wdata(wdata),
        .rdata(rdata),
        .wr_en(wr_en),
        .rd_en(rd_en),
        
        .tx_fifo_data_in(wdata[DATA_BITS-1:0]),
        .tx_fifo_write(tx_fifo_write),
        .tx_fifo_full(tx_fifo_full),
        .rx_fifo_data_out(rx_fifo_data_out),
        .rx_fifo_read(rx_fifo_read),
        .rx_fifo_empty(rx_fifo_empty),
        
        .tx_fifo_level(tx_fifo_level),
        .rx_fifo_level(rx_fifo_level),
        
        .uart_en(uart_en),
        .tx_fifo_reset(tx_fifo_reset),
        .rx_fifo_reset(rx_fifo_reset),
        .loopback_en(loopback_en),
        .tx_fifo_threshold(tx_fifo_threshold),
        .rx_fifo_threshold(rx_fifo_threshold),
        .baud_div(baud_div),
        
        .tx_fifo_empty(tx_fifo_empty),
        .tx_fifo_threshold_reached(tx_fifo_threshold_reached),
        .rx_fifo_full(rx_fifo_full),
        .rx_fifo_threshold_reached(rx_fifo_threshold_reached),
        .rx_frame_error(rx_frame_error),
        .rx_overrun(rx_overrun),
        
        .tx_empty_irq(tx_empty_irq),
        .rx_ready_irq(rx_ready_irq),
        .rx_overrun_irq(rx_overrun_irq)
    );
    
    // TX FIFO
    uart_fifo #(
        .DEPTH(TX_FIFO_DEPTH),
        .WIDTH(DATA_BITS)
    ) tx_fifo (
        .clk(clk),
        .rst_n(rst_n & ~tx_fifo_reset),
        .write_en(tx_fifo_write),
        .read_en(tx_fifo_read),
        .data_in(wdata[DATA_BITS-1:0]),
        .data_out(tx_fifo_data_out),
        .empty(tx_fifo_empty),
        .full(tx_fifo_full),
        .level(tx_fifo_level),
        .threshold(tx_fifo_threshold),
        .threshold_reached(tx_fifo_threshold_reached)
    );
    
    // RX FIFO
    uart_fifo #(
        .DEPTH(RX_FIFO_DEPTH),
        .WIDTH(DATA_BITS)
    ) rx_fifo (
        .clk(clk),
        .rst_n(rst_n & ~rx_fifo_reset),
        .write_en(rx_fifo_write),
        .read_en(rx_fifo_read),
        .data_in(rx_fifo_data_in),
        .data_out(rx_fifo_data_out),
        .empty(rx_fifo_empty),
        .full(rx_fifo_full),
        .level(rx_fifo_level),
        .threshold(rx_fifo_threshold),
        .threshold_reached(rx_fifo_threshold_reached)
    );

    // Baud rate generator
    wire baud_tick;
    uart_baud_gen baud_gen (
        .clk(clk),
        .rst_n(rst_n),
        .enable(uart_en),
        .divisor(baud_div),
        .tick(baud_tick)
    );
    
    // TX logic
    uart_tx #(
        .DATA_BITS(DATA_BITS),
        .STOP_BITS(STOP_BITS)
    ) tx_logic (
        .clk(clk),
        .rst_n(rst_n),
        .enable(uart_en),
        .baud_tick(baud_tick),
        .data_in(tx_fifo_data_out),
        .tx_start(~tx_fifo_empty & ~tx_busy),
        .tx(loopback_rx),
        .busy(tx_busy),
        .done(tx_fifo_read)
    );
    
    // RX logic
    uart_rx #(
        .DATA_BITS(DATA_BITS),
        .STOP_BITS(STOP_BITS),
        .OVERSAMPLE(OVERSAMPLE)
    ) rx_logic (
        .clk(clk),
        .rst_n(rst_n),
        .enable(uart_en),
        .baud_tick(baud_tick),
        .rx(loopback_en ? loopback_rx : rx),
        .data_out(rx_fifo_data_in),
        .data_ready(rx_data_ready),
        .frame_error(rx_frame_error),
        .overrun(rx_overrun)
    );
    
    // Connect RX data to FIFO
    assign rx_fifo_write = rx_data_ready & ~rx_fifo_full;
    
    // Loopback support
    wire loopback_rx;
    assign tx = loopback_rx;

endmodule