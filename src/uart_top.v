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
    output wire rx_overrun_irq,   // RX overrun error interrupt
    
    // Debug signals
    output wire dbg_tx_serial,    // TX serial output for debug
    output wire dbg_rx_input,     // RX input after loopback mux for debug
    output wire dbg_rx_data_ready, // RX data ready signal for debug
    output wire dbg_baud_tick,    // Baud tick for debug
    output wire [2:0] dbg_tx_state // TX state machine state for debug
);

    // Internal signals
    wire tx_fifo_write;
    wire tx_fifo_read;
    wire tx_fifo_empty;
    wire tx_fifo_full;
    wire [DATA_BITS-1:0] tx_fifo_data_out;
    wire [DATA_BITS-1:0] tx_fifo_data_in;
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
    
    // FIFO level signals
    wire [7:0] tx_fifo_level;
    wire [7:0] rx_fifo_level;
    
    // Loopback and transmit signals
    wire tx_serial;
    reg tx_serial_reg;
    wire rx_input;
    
    // TX triggering logic
    reg tx_trigger;
    reg [1:0] tx_state;
    localparam TX_IDLE = 2'd0;
    localparam TX_START = 2'd1;
    localparam TX_WAIT = 2'd2;
    
    // TX state machine for reliable triggering with TX output registration
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state <= TX_IDLE;
            tx_trigger <= 1'b0;
            tx_serial_reg <= 1'b1; // Idle state is high
        end else begin
            // Register TX output for cleaner loopback timing
            tx_serial_reg <= tx_serial;
            
            case (tx_state)
                TX_IDLE: begin
                    if (~tx_fifo_empty & ~tx_busy) begin
                        tx_state <= TX_START;
                        tx_trigger <= 1'b1;
                    end
                end
                TX_START: begin
                    tx_trigger <= 1'b0;
                    tx_state <= TX_WAIT;
                end
                TX_WAIT: begin
                    if (tx_busy)
                        tx_state <= TX_WAIT;
                    else
                        tx_state <= TX_IDLE;
                end
                default: tx_state <= TX_IDLE;
            endcase
        end
    end
    
    // Create internal data signal from wdata
    assign tx_fifo_data_in = wdata[DATA_BITS-1:0];
    
    // Setup loopback paths with registered TX for better timing
    assign rx_input = loopback_en ? tx_serial_reg : rx;
    assign tx = tx_serial;
    
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
        
        .tx_fifo_data_in(tx_fifo_data_in),
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
        .data_in(tx_fifo_data_in),
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
    wire [2:0] tx_state_debug;
    uart_tx tx_logic (
        .clk(clk),
        .rst_n(rst_n),
        .enable(uart_en),
        .baud_tick(baud_tick),
        .data_in(tx_fifo_data_out),
        .tx_start(tx_trigger),
        .tx(tx_serial),
        .busy(tx_busy),
        .done(tx_fifo_read),
        .dbg_tx_state(tx_state_debug)
    );
    
    // RX logic
    uart_rx rx_logic (
        .clk(clk),
        .rst_n(rst_n),
        .enable(uart_en),
        .baud_tick(baud_tick),
        .rx(rx_input),
        .data_out(rx_fifo_data_in),
        .data_ready(rx_data_ready),
        .frame_error(rx_frame_error),
        .overrun(rx_overrun)
    );
    
    // Connect RX data to FIFO
    assign rx_fifo_write = rx_data_ready & ~rx_fifo_full;

    // Debug signals
    assign dbg_tx_serial = tx_serial;
    assign dbg_rx_input = rx_input;
    assign dbg_rx_data_ready = rx_data_ready;
    assign dbg_baud_tick = baud_tick;
    assign dbg_tx_state = tx_state_debug;

endmodule