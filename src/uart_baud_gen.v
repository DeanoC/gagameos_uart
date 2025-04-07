//
// UART Baud Rate Generator
// Generates baud tick from input clock using programmable divider
//
`timescale 1ns/1ps

module uart_baud_gen (
    input wire clk,              // Input clock
    input wire rst_n,            // Active low reset
    input wire enable,           // Enable signal
    input wire [15:0] divisor,   // Baud rate divisor
    output reg tick              // Baud tick output
);
    // Counter for clock division
    reg [15:0] counter;

    // Baud tick generation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 16'd0;
            tick <= 1'b0;
        end else if (!enable) begin
            // Hold counter and tick at 0 when disabled
            counter <= 16'd0;
            tick <= 1'b0;
        end else begin
            if (counter >= divisor - 1) begin
                // Reset counter and generate tick
                counter <= 16'd0;
                tick <= 1'b1;
            end else begin
                // Increment counter and no tick
                counter <= counter + 16'd1;
                tick <= 1'b0;
            end
        end
    end

endmodule