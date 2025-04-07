//
// UART Top Level Testbench
//
`timescale 1ns/1ps

module tb_uart_top;

    // Parameters
    parameter CLK_PERIOD = 20; // 50MHz clock
    parameter DATA_BITS = 8;
    parameter STOP_BITS = 1;
    parameter BAUD_RATE = 115200;
    parameter CLK_FREQ = 50000000;
    parameter DIVISOR = CLK_FREQ / (BAUD_RATE * 16);
    
    // Signals
    reg clk;
    reg rst_n;
    reg rx;
    wire tx;
    
    reg [3:0] addr;
    reg [31:0] wdata;
    wire [31:0] rdata;
    reg wr_en;
    reg rd_en;
    
    wire tx_empty_irq;
    wire rx_ready_irq;
    wire rx_overrun_irq;
    
    // Register addresses
    localparam REG_CTRL       = 4'h0;  // Control register
    localparam REG_STATUS     = 4'h1;  // Status register
    localparam REG_BAUD_DIV   = 4'h2;  // Baud rate divisor
    localparam REG_TX_DATA    = 4'h3;  // TX data register
    localparam REG_RX_DATA    = 4'h4;  // RX data register
    localparam REG_INT_ENABLE = 4'h5;  // Interrupt enable register
    localparam REG_INT_STATUS = 4'h6;  // Interrupt status register
    
    // Instantiate the UART top module
    uart_top #(
        .CLK_FREQ_HZ(CLK_FREQ),
        .DEFAULT_BAUD(BAUD_RATE),
        .TX_FIFO_DEPTH(16),
        .RX_FIFO_DEPTH(16),
        .DATA_BITS(DATA_BITS),
        .STOP_BITS(STOP_BITS),
        .PARITY("NONE"),
        .OVERSAMPLE(16)
    ) uart_dut (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .tx(tx),
        .addr(addr),
        .wdata(wdata),
        .rdata(rdata),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .tx_empty_irq(tx_empty_irq),
        .rx_ready_irq(rx_ready_irq),
        .rx_overrun_irq(rx_overrun_irq)
    );
    
    // Clock generation
    always begin
        #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Task for register write
    task write_reg;
        input [3:0] reg_addr;
        input [31:0] reg_data;
        begin
            @(posedge clk);
            addr = reg_addr;
            wdata = reg_data;
            wr_en = 1'b1;
            @(posedge clk);
            wr_en = 1'b0;
        end
    endtask
    
    // Task for register read
    task read_reg;
        input [3:0] reg_addr;
        output [31:0] reg_data;
        begin
            @(posedge clk);
            addr = reg_addr;
            rd_en = 1'b1;
            @(posedge clk);
            rd_en = 1'b0;
            reg_data = rdata;
        end
    endtask
    
    // Task to send a byte via MMIO to TX
    task send_byte;
        input [7:0] data;
        reg [31:0] status;
        begin
            // Check if TX FIFO is full
            read_reg(REG_STATUS, status);
            if (status[1]) begin
                $display("TX FIFO full, cannot send byte");
            end else begin
                write_reg(REG_TX_DATA, {24'h0, data});
                $display("Sent byte: 0x%02x", data);
            end
        end
    endtask
    
    // Task to receive a byte from RX FIFO
    task receive_byte;
        output [7:0] data;
        reg [31:0] status;
        reg [31:0] rx_data;
        begin
            // Check if RX FIFO is empty
            read_reg(REG_STATUS, status);
            if (status[2]) begin
                $display("RX FIFO empty, no data to read");
                data = 8'h00;
            end else begin
                read_reg(REG_RX_DATA, rx_data);
                data = rx_data[7:0];
                $display("Received byte: 0x%02x", data);
            end
        end
    endtask
    
    // UART RX simulation (bit-banging the RX line)
    task uart_rx_send;
        input [7:0] data;
        integer i;
        begin
            // Start bit
            rx = 1'b0;
            repeat (16) @(posedge clk);
            
            // Data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                rx = data[i];
                repeat (16) @(posedge clk);
            end
            
            // Stop bit
            rx = 1'b1;
            repeat (16) @(posedge clk);
            
            // Extra idle time
            repeat (16) @(posedge clk);
        end
    endtask
    
    // Test sequence
    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        rx = 1;
        addr = 0;
        wdata = 0;
        wr_en = 0;
        rd_en = 0;
        
        // Reset sequence
        repeat (10) @(posedge clk);
        rst_n = 1;
        repeat (5) @(posedge clk);
        
        // Display test start
        $display("Starting UART test...");
        
        // Configure UART
        $display("Configuring UART with baud divisor: %0d", DIVISOR);
        write_reg(REG_BAUD_DIV, DIVISOR);
        
        // Enable UART
        $display("Enabling UART");
        write_reg(REG_CTRL, 1); // Enable bit
        
        // Send data via TX
        $display("Sending TX data test");
        send_byte(8'h55); // ASCII 'U'
        send_byte(8'h41); // ASCII 'A'
        send_byte(8'h52); // ASCII 'R'
        send_byte(8'h54); // ASCII 'T'
        
        // Wait for TX to complete (simplified)
        repeat (2000) @(posedge clk);
        
        // Test loopback mode
        $display("Testing loopback mode");
        write_reg(REG_CTRL, 9); // Enable + loopback
        
        // Send data in loopback mode
        send_byte(8'h4C); // ASCII 'L'
        send_byte(8'h4F); // ASCII 'O'
        send_byte(8'h4F); // ASCII 'O'
        send_byte(8'h50); // ASCII 'P'
        
        // Wait for data to go through loopback
        repeat (1000) @(posedge clk);
        
        // Read loopback data
        $display("Reading loopback data");
        begin
            reg [7:0] rx_byte;
            receive_byte(rx_byte);
            receive_byte(rx_byte);
            receive_byte(rx_byte);
            receive_byte(rx_byte);
        end
        
        // Disable loopback
        write_reg(REG_CTRL, 1); // Just enable
        
        // Test direct UART RX
        $display("Testing direct UART RX");
        uart_rx_send(8'h48); // ASCII 'H'
        uart_rx_send(8'h45); // ASCII 'E'
        uart_rx_send(8'h4C); // ASCII 'L'
        uart_rx_send(8'h4C); // ASCII 'L'
        uart_rx_send(8'h4F); // ASCII 'O'
        
        // Wait for RX processing
        repeat (1000) @(posedge clk);
        
        // Read direct UART RX data
        $display("Reading direct RX data");
        begin
            reg [7:0] rx_byte;
            receive_byte(rx_byte);
            receive_byte(rx_byte);
            receive_byte(rx_byte);
            receive_byte(rx_byte);
            receive_byte(rx_byte);
        end
        
        // Test complete
        $display("Test complete!");
        #1000;
        $finish;
    end
    
    // Waveform dump for debug
    initial begin
        $dumpfile("tb_uart_top.vcd");
        $dumpvars(0, tb_uart_top);
    end

endmodule