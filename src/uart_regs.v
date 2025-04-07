//
// UART Register Interface Module
// Implements the memory-mapped register interface for the UART
//
`timescale 1ns/1ps

module uart_regs #(
    parameter DATA_BITS = 8
) (
    input wire clk,               // Input clock
    input wire rst_n,             // Active low reset
    
    // MMIO interface
    input wire [3:0] addr,        // Register address
    input wire [31:0] wdata,      // Write data
    output reg [31:0] rdata,      // Read data
    input wire wr_en,             // Write enable
    input wire rd_en,             // Read enable
    
    // TX FIFO interface
    output wire [DATA_BITS-1:0] tx_fifo_data_in,  // TX data to FIFO
    output reg tx_fifo_write,     // TX FIFO write enable
    input wire tx_fifo_full,      // TX FIFO full signal
    
    // RX FIFO interface
    input wire [DATA_BITS-1:0] rx_fifo_data_out,  // RX data from FIFO
    output reg rx_fifo_read,      // RX FIFO read enable
    input wire rx_fifo_empty,     // RX FIFO empty signal
    
    // FIFO status
    input wire [7:0] tx_fifo_level,  // TX FIFO level
    input wire [7:0] rx_fifo_level,  // RX FIFO level
    
    // Control signals
    output reg uart_en,           // UART enable
    output reg tx_fifo_reset,     // TX FIFO reset
    output reg rx_fifo_reset,     // RX FIFO reset
    output reg loopback_en,       // Loopback mode enable
    output reg [7:0] tx_fifo_threshold,  // TX FIFO threshold
    output reg [7:0] rx_fifo_threshold,  // RX FIFO threshold
    output reg [15:0] baud_div,   // Baud rate divisor
    
    // Status signals
    input wire tx_fifo_empty,            // TX FIFO empty
    input wire tx_fifo_threshold_reached,  // TX FIFO threshold reached
    input wire rx_fifo_full,             // RX FIFO full
    input wire rx_fifo_threshold_reached,  // RX FIFO threshold reached
    input wire rx_frame_error,           // RX frame error
    input wire rx_overrun,               // RX overrun error
    
    // Interrupt outputs
    output reg tx_empty_irq,      // TX FIFO empty interrupt
    output reg rx_ready_irq,      // RX data ready interrupt
    output reg rx_overrun_irq     // RX overrun error interrupt
);

    // Register addresses
    localparam REG_CTRL       = 4'h0;  // Control register
    localparam REG_STATUS     = 4'h1;  // Status register
    localparam REG_BAUD_DIV   = 4'h2;  // Baud rate divisor
    localparam REG_TX_DATA    = 4'h3;  // TX data register
    localparam REG_RX_DATA    = 4'h4;  // RX data register
    localparam REG_INT_ENABLE = 4'h5;  // Interrupt enable register
    localparam REG_INT_STATUS = 4'h6;  // Interrupt status register
    
    // Internal registers
    reg [31:0] ctrl_reg;
    reg [31:0] status_reg;
    reg [31:0] int_enable_reg;
    reg [31:0] int_status_reg;
    
    // We no longer need to assign tx_fifo_data_in here
    // as it's now handled in uart_top.v
    
    // Extract control signals from registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_en <= 1'b0;
            tx_fifo_reset <= 1'b1;  // Reset FIFOs on power-up
            rx_fifo_reset <= 1'b1;
            loopback_en <= 1'b0;
            tx_fifo_threshold <= 8'd1;
            rx_fifo_threshold <= 8'd1;
            baud_div <= 16'd27;  // Default to ~115200 baud at 50MHz with 16x oversample
        end else begin
            // Default values
            tx_fifo_reset <= 1'b0;
            rx_fifo_reset <= 1'b0;
            
            // Control register write
            if (wr_en && addr == REG_CTRL) begin
                uart_en <= wdata[0];
                tx_fifo_reset <= wdata[1];
                rx_fifo_reset <= wdata[2];
                loopback_en <= wdata[3];
                tx_fifo_threshold <= wdata[15:8];
                rx_fifo_threshold <= wdata[23:16];
                ctrl_reg <= wdata;
            end
            
            // Baud rate divisor write
            if (wr_en && addr == REG_BAUD_DIV) begin
                baud_div <= wdata[15:0];
            end
            
            // Interrupt enable register write
            if (wr_en && addr == REG_INT_ENABLE) begin
                int_enable_reg <= wdata;
            end
        end
    end
    
    // Read logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata <= 32'd0;
            rx_fifo_read <= 1'b0;
        end else begin
            rx_fifo_read <= 1'b0;
            
            if (rd_en) begin
                case (addr)
                    REG_CTRL: begin
                        rdata <= ctrl_reg;
                    end
                    
                    REG_STATUS: begin
                        rdata <= {
                            8'd0, // Reserved
                            rx_fifo_level, // RX FIFO level
                            tx_fifo_level, // TX FIFO level
                            rx_overrun,
                            rx_frame_error,
                            rx_fifo_threshold_reached,
                            tx_fifo_threshold_reached,
                            rx_fifo_full,
                            rx_fifo_empty,
                            tx_fifo_full,
                            tx_fifo_empty
                        };
                    end
                    
                    REG_BAUD_DIV: begin
                        rdata <= {16'd0, baud_div};
                    end
                    
                    REG_RX_DATA: begin
                        if (!rx_fifo_empty) begin
                            rdata <= {24'd0, rx_fifo_data_out};
                            rx_fifo_read <= 1'b1; // Auto-increment read pointer
                        end else begin
                            rdata <= 32'd0;
                        end
                    end
                    
                    REG_INT_ENABLE: begin
                        rdata <= int_enable_reg;
                    end
                    
                    REG_INT_STATUS: begin
                        rdata <= int_status_reg;
                    end
                    
                    default: begin
                        rdata <= 32'd0;
                    end
                endcase
            end
        end
    end
    
    // Write to TX FIFO
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_fifo_write <= 1'b0;
        end else begin
            tx_fifo_write <= 1'b0;
            
            if (wr_en && addr == REG_TX_DATA && !tx_fifo_full) begin
                tx_fifo_write <= 1'b1;
            end
        end
    end
    
    // Interrupt generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            int_status_reg <= 32'd0;
            tx_empty_irq <= 1'b0;
            rx_ready_irq <= 1'b0;
            rx_overrun_irq <= 1'b0;
        end else begin
            // Update interrupt status register
            int_status_reg <= {
                29'd0,  // Reserved
                rx_overrun,
                !rx_fifo_empty,
                tx_fifo_empty
            };
            
            // Generate interrupts based on enabled conditions
            tx_empty_irq <= tx_fifo_empty && int_enable_reg[0];
            rx_ready_irq <= !rx_fifo_empty && int_enable_reg[1];
            rx_overrun_irq <= rx_overrun && int_enable_reg[2];
        end
    end

endmodule