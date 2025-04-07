//
// UART Receiver Module
// Implements the receive side of the UART with oversampling
//
`timescale 1ns/1ps

module uart_rx #(
    parameter DATA_BITS = 8,      // Data bits (8 for 8N1)
    parameter STOP_BITS = 1,      // Stop bits (1 for 8N1)
    parameter OVERSAMPLE = 16     // Oversampling factor (16x typical)
) (
    input wire clk,               // Input clock
    input wire rst_n,             // Active low reset
    input wire enable,            // Enable signal
    input wire baud_tick,         // Baud rate tick from generator
    input wire rx,                // RX input signal
    output reg [DATA_BITS-1:0] data_out,  // Received data
    output reg data_ready,        // Data ready signal
    output reg frame_error,       // Framing error signal
    output reg overrun            // Overrun error signal
);

    // RX state machine states
    localparam IDLE        = 3'd0;
    localparam START_BIT   = 3'd1;
    localparam DATA_BITS   = 3'd2;
    localparam STOP_BITS   = 3'd3;
    localparam WAIT_IDLE   = 3'd4;

    // Oversampling counter values
    localparam SAMPLE_MIDDLE = (OVERSAMPLE / 2);

    // Receiver registers
    reg [2:0] state;
    reg [4:0] oversample_counter;  // For 16x oversampling
    reg [3:0] bit_counter;
    reg [DATA_BITS-1:0] shift_reg;
    reg [3:0] stop_bit_counter;
    reg [2:0] rx_sync;            // For synchronization/glitch filtering
    reg data_ready_int;           // Internal data ready
    
    // Synchronize RX input (to avoid metastability)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rx_sync <= 3'b111;
        else
            rx_sync <= {rx_sync[1:0], rx};
    end

    // Filtered RX input (majority filter for glitch rejection)
    wire rx_filtered = (rx_sync[0] & rx_sync[1]) |
                       (rx_sync[1] & rx_sync[2]) |
                       (rx_sync[0] & rx_sync[2]);

    // RX state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            oversample_counter <= 0;
            bit_counter <= 0;
            shift_reg <= 0;
            stop_bit_counter <= 0;
            data_out <= 0;
            data_ready <= 1'b0;
            data_ready_int <= 1'b0;
            frame_error <= 1'b0;
            overrun <= 1'b0;
        end else if (!enable) begin
            state <= IDLE;
            oversample_counter <= 0;
            bit_counter <= 0;
            data_ready <= 1'b0;
            data_ready_int <= 1'b0;
            frame_error <= 1'b0;
        end else begin
            // Data ready is asserted for one clock cycle
            data_ready <= data_ready_int;
            data_ready_int <= 1'b0;
            
            // Check for overrun error
            if (data_ready && data_ready_int)
                overrun <= 1'b1;
                
            // Process baud ticks
            if (baud_tick) begin
                case (state)
                    IDLE: begin
                        if (!rx_filtered) begin
                            // Start bit detected
                            state <= START_BIT;
                            oversample_counter <= 0;
                            frame_error <= 1'b0;
                        end
                    end
                    
                    START_BIT: begin
                        // Oversample start bit
                        if (oversample_counter == SAMPLE_MIDDLE) begin
                            // Verify start bit is still low
                            if (!rx_filtered) begin
                                state <= DATA_BITS;
                                oversample_counter <= 0;
                                bit_counter <= 0;
                            end else begin
                                // False start - go back to idle
                                state <= IDLE;
                            end
                        end else begin
                            oversample_counter <= oversample_counter + 5'd1;
                        end
                    end
                    
                    DATA_BITS: begin
                        // Oversample data bits
                        if (oversample_counter == SAMPLE_MIDDLE) begin
                            // Sample data in the middle of bit
                            shift_reg <= {rx_filtered, shift_reg[DATA_BITS-1:1]};
                            
                            if (bit_counter == DATA_BITS - 1) begin
                                state <= STOP_BITS;
                                oversample_counter <= 0;
                                stop_bit_counter <= 0;
                            end else begin
                                bit_counter <= bit_counter + 4'd1;
                            end
                        end
                        
                        // Increment oversample counter
                        if (oversample_counter == OVERSAMPLE - 1)
                            oversample_counter <= 0;
                        else
                            oversample_counter <= oversample_counter + 5'd1;
                    end
                    
                    STOP_BITS: begin
                        // Oversample stop bits
                        if (oversample_counter == SAMPLE_MIDDLE) begin
                            // Check stop bit
                            if (!rx_filtered) begin
                                // Stop bit should be high - frame error
                                frame_error <= 1'b1;
                            end else if (stop_bit_counter == STOP_BITS - 1) begin
                                // Valid stop bit(s)
                                data_out <= shift_reg;
                                data_ready_int <= 1'b1;
                            end
                            
                            if (stop_bit_counter == STOP_BITS - 1) begin
                                state <= WAIT_IDLE;
                            end else begin
                                stop_bit_counter <= stop_bit_counter + 4'd1;
                            end
                        end
                        
                        // Increment oversample counter
                        if (oversample_counter == OVERSAMPLE - 1)
                            oversample_counter <= 0;
                        else
                            oversample_counter <= oversample_counter + 5'd1;
                    end
                    
                    WAIT_IDLE: begin
                        // Wait for RX to return to idle (high)
                        if (rx_filtered)
                            state <= IDLE;
                    end
                    
                    default: state <= IDLE;
                endcase
            end
        end
    end

endmodule