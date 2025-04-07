//
// Parameterized FIFO Module for UART
// Implements a parameterized depth FIFO with level tracking
//
`timescale 1ns/1ps

module uart_fifo #(
    parameter DEPTH = 16,        // FIFO depth (must be power of 2)
    parameter WIDTH = 8,         // Data width
    parameter ADDR_WIDTH = $clog2(DEPTH)  // Address width
) (
    input wire clk,               // Input clock
    input wire rst_n,             // Active low reset
    input wire write_en,          // Write enable
    input wire read_en,           // Read enable
    input wire [WIDTH-1:0] data_in,  // Data input
    output reg [WIDTH-1:0] data_out,  // Data output
    output wire empty,            // FIFO empty flag
    output wire full,             // FIFO full flag
    output wire [ADDR_WIDTH:0] level,  // Fill level
    input wire [ADDR_WIDTH:0] threshold,  // Threshold level
    output wire threshold_reached  // Threshold reached indicator
);

    // Memory array for FIFO
    reg [WIDTH-1:0] mem [0:DEPTH-1];
    
    // Pointers for read and write
    reg [ADDR_WIDTH:0] read_ptr;
    reg [ADDR_WIDTH:0] write_ptr;
    
    // Gray code pointers for clock domain crossing (if needed)
    wire [ADDR_WIDTH:0] write_gray;
    wire [ADDR_WIDTH:0] read_gray;
    
    // Convert binary to gray code
    assign write_gray = write_ptr ^ (write_ptr >> 1);
    assign read_gray = read_ptr ^ (read_ptr >> 1);
    
    // FIFO status signals
    assign empty = (read_ptr == write_ptr);
    assign full = ((write_ptr[ADDR_WIDTH-1:0] == read_ptr[ADDR_WIDTH-1:0]) && 
                  (write_ptr[ADDR_WIDTH] != read_ptr[ADDR_WIDTH]));
    
    // Calculate FIFO level
    assign level = write_ptr - read_ptr;
    
    // Threshold comparison
    assign threshold_reached = (level >= threshold);
    
    // Write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr <= 0;
        end else if (write_en && !full) begin
            mem[write_ptr[ADDR_WIDTH-1:0]] <= data_in;
            write_ptr <= write_ptr + 1'b1;
        end
    end
    
    // Read logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_ptr <= 0;
            data_out <= {WIDTH{1'b0}};
        end else begin
            if (read_en && !empty) begin
                data_out <= mem[read_ptr[ADDR_WIDTH-1:0]];
                read_ptr <= read_ptr + 1'b1;
            end
        end
    end

endmodule