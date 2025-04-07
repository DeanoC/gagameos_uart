//
// UART Transmitter Module
// Implements the transmit side of the UART
//
`timescale 1ns/1ps

module uart_tx #(
    parameter DATA_BITS = 8,     // Data bits (8 for 8N1)
    parameter STOP_BITS = 1      // Stop bits (1 for 8N1)
) (
    input wire clk,              // Input clock
    input wire rst_n,            // Active low reset
    input wire enable,           // Enable signal
    input wire baud_tick,        // Baud rate tick from generator
    input wire [DATA_BITS-1:0] data_in,  // Transmit data
    input wire tx_start,         // Start transmit
    output reg tx,               // TX output signal
    output wire busy,            // TX busy signal
    output reg done              // TX done signal
);

    // TX state machine states
    localparam IDLE        = 3'd0;
    localparam START_BIT   = 3'd1;
    localparam DATA_BITS   = 3'd2;
    localparam STOP_BITS   = 3'd3;
    localparam DONE        = 3'd4;

    // Transmitter registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] bit_counter;
    reg [DATA_BITS-1:0] shift_reg;
    reg [3:0] stop_bit_counter;

    // Busy signal generation
    assign busy = (state != IDLE);

    // TX state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            bit_counter <= 0;
            shift_reg <= 0;
            stop_bit_counter <= 0;
            tx <= 1'b1;          // Idle state is high
            done <= 1'b0;
        end else if (!enable) begin
            state <= IDLE;
            bit_counter <= 0;
            shift_reg <= 0;
            stop_bit_counter <= 0;
            tx <= 1'b1;          // Idle state is high
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1'b1;  // Idle state is high
                    done <= 1'b0;
                    
                    if (tx_start) begin
                        state <= START_BIT;
                        shift_reg <= data_in;
                    end
                end
                
                START_BIT: begin
                    tx <= 1'b0;  // Start bit is low
                    
                    if (baud_tick) begin
                        state <= DATA_BITS;
                        bit_counter <= 0;
                    end
                end
                
                DATA_BITS: begin
                    tx <= shift_reg[0]; // LSB first
                    
                    if (baud_tick) begin
                        shift_reg <= {1'b0, shift_reg[DATA_BITS-1:1]}; // Shift right
                        
                        if (bit_counter == DATA_BITS - 1) begin
                            state <= STOP_BITS;
                            stop_bit_counter <= 0;
                        end else begin
                            bit_counter <= bit_counter + 4'd1;
                        end
                    end
                end
                
                STOP_BITS: begin
                    tx <= 1'b1;  // Stop bit is high
                    
                    if (baud_tick) begin
                        if (stop_bit_counter == STOP_BITS - 1) begin
                            state <= DONE;
                        end else begin
                            stop_bit_counter <= stop_bit_counter + 4'd1;
                        end
                    end
                end
                
                DONE: begin
                    tx <= 1'b1;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule