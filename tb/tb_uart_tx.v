// Testbench for UART transmitter
`timescale 1ns/1ps

module tb_uart_tx;
    // Parameters
    parameter DATA_BITS = 8;
    parameter STOP_BITS = 1;
    
    // Testbench signals
    reg clk;
    reg rst_n;
    reg enable;
    reg baud_tick;
    reg [DATA_BITS-1:0] data_in;
    reg tx_start;
    wire tx;
    wire busy;
    wire done;
    wire [2:0] dbg_tx_state;
    
    // Test variables
    integer i, j, bit_index;
    integer test_count;
    reg [DATA_BITS-1:0] test_data;
    reg [7:0] received_data;
    
    // Clock period definitions
    localparam CLK_PERIOD = 20; // 50MHz clock
    
    // State definitions for clarity
    localparam IDLE = 3'd0;
    localparam START_BIT = 3'd1;
    localparam DATA_STATE = 3'd2;
    localparam STOP_STATE = 3'd3;
    localparam DONE = 3'd4;
    
    // Instantiate the Unit Under Test (UUT)
    uart_tx #(
        .DATA_BITS(DATA_BITS),
        .STOP_BITS(STOP_BITS)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .baud_tick(baud_tick),
        .data_in(data_in),
        .tx_start(tx_start),
        .tx(tx),
        .busy(busy),
        .done(done),
        .dbg_tx_state(dbg_tx_state)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Baud tick generation - simulate the baud generator
    task generate_baud_ticks;
        input integer num_ticks;
        begin
            repeat (num_ticks) begin
                baud_tick = 1;
                #CLK_PERIOD;
                baud_tick = 0;
                #(CLK_PERIOD*15); // Simulate 16x oversampling
            end
        end
    endtask
    
    // Transmit one byte and verify the waveform
    task transmit_and_verify;
        input [DATA_BITS-1:0] data_to_send;
        begin
            // Load data and start transmission
            @(posedge clk);
            data_in = data_to_send;
            tx_start = 1;
            @(posedge clk);
            tx_start = 0;
            
            // Wait for busy to assert
            wait(busy);
            $display("Transmission started, data: 0x%h", data_to_send);
            
            // Verify start bit (should be low)
            generate_baud_ticks(1);
            if (tx === 1'b0)
                $display("Start bit verified (low)");
            else
                $display("ERROR: Start bit incorrect, tx = %b", tx);
            
            // Capture and verify data bits
            received_data = 0;
            for (bit_index = 0; bit_index < DATA_BITS; bit_index = bit_index + 1) begin
                generate_baud_ticks(1);
                received_data = {tx, received_data[7:1]}; // Shift in LSB first
                $display("Bit %0d: tx = %b", bit_index, tx);
            end
            
            // Verify data sent matches what was received
            if (received_data === data_to_send)
                $display("Data bits verified, received: 0x%h", received_data);
            else
                $display("ERROR: Data mismatch, sent: 0x%h, received: 0x%h", data_to_send, received_data);
            
            // Verify stop bit(s)
            for (j = 0; j < STOP_BITS; j = j + 1) begin
                generate_baud_ticks(1);
                if (tx === 1'b1)
                    $display("Stop bit %0d verified (high)", j);
                else
                    $display("ERROR: Stop bit %0d incorrect, tx = %b", j, tx);
            end
            
            // Wait for done signal
            wait(done);
            @(posedge clk);
            
            // Verify return to idle
            if (dbg_tx_state == IDLE && !busy)
                $display("Returned to idle state correctly");
            else
                $display("ERROR: Did not return to idle state correctly");
            
            // Allow some idle time
            #(CLK_PERIOD*10);
        end
    endtask
    
    // Test procedure
    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        enable = 0;
        baud_tick = 0;
        data_in = 0;
        tx_start = 0;
        test_count = 0;
        
        // Reset sequence
        #(CLK_PERIOD*5);
        rst_n = 1;
        #(CLK_PERIOD*2);
        
        // Test case 1: Verify disabled state
        $display("\nTest %0d: Verify disabled state", test_count);
        enable = 0;
        data_in = 8'hA5;
        tx_start = 1;
        #(CLK_PERIOD*2);
        tx_start = 0;
        
        if (tx === 1'b1 && !busy && dbg_tx_state == IDLE)
            $display("PASS: Transmitter remains idle when disabled");
        else
            $display("FAIL: Transmitter not idle when disabled. tx=%b, busy=%b, state=%0d", 
                     tx, busy, dbg_tx_state);
        test_count++;
        
        // Enable the transmitter for the rest of the tests
        enable = 1;
        #(CLK_PERIOD*2);
        
        // Test case 2: Transmit a byte with value 0x55 (alternating bits)
        $display("\nTest %0d: Transmit 0x55 (alternating bits)", test_count);
        transmit_and_verify(8'h55);
        test_count++;
        
        // Test case 3: Transmit a byte with value 0xAA (alternating bits, opposite of test 2)
        $display("\nTest %0d: Transmit 0xAA (alternating bits)", test_count);
        transmit_and_verify(8'hAA);
        test_count++;
        
        // Test case 4: Transmit a byte with all zeros
        $display("\nTest %0d: Transmit 0x00 (all zeros)", test_count);
        transmit_and_verify(8'h00);
        test_count++;
        
        // Test case 5: Transmit a byte with all ones
        $display("\nTest %0d: Transmit 0xFF (all ones)", test_count);
        transmit_and_verify(8'hFF);
        test_count++;
        
        // Test case 6: Transmit multiple bytes in sequence
        $display("\nTest %0d: Transmit multiple bytes in sequence", test_count);
        transmit_and_verify(8'h12);
        transmit_and_verify(8'h34);
        transmit_and_verify(8'h56);
        test_count++;
        
        // Test case 7: Test tx_start pulse width (should trigger on single cycle)
        $display("\nTest %0d: Test tx_start pulse width", test_count);
        
        // Single cycle pulse
        @(posedge clk);
        data_in = 8'hA1;
        tx_start = 1;
        @(posedge clk);
        tx_start = 0;
        
        wait(busy);
        $display("PASS: Transmitter started with single-cycle tx_start pulse");
        
        // Complete the transmission and wait for idle
        while (busy) begin
            generate_baud_ticks(1);
        end
        test_count++;
        
        // Test case 8: Test disabling during transmission
        $display("\nTest %0d: Test disabling during transmission", test_count);
        
        // Start a transmission
        @(posedge clk);
        data_in = 8'hB2;
        tx_start = 1;
        @(posedge clk);
        tx_start = 0;
        
        wait(busy);
        generate_baud_ticks(2); // Let it start transmitting
        
        // Disable the transmitter mid-transmission
        enable = 0;
        #(CLK_PERIOD*2);
        
        if (!busy && tx === 1'b1)
            $display("PASS: Transmitter returned to idle when disabled mid-transmission");
        else
            $display("FAIL: Transmitter did not return to idle when disabled. busy=%b, tx=%b", 
                     busy, tx);
        
        // Re-enable for next test
        enable = 1;
        #(CLK_PERIOD*5);
        test_count++;
        
        // Finish simulation
        $display("\nAll tests completed");
        $finish;
    end
    
    // Dump waveforms
    initial begin
        $dumpfile("tb_uart_tx.vcd");
        $dumpvars(0, tb_uart_tx);
    end
    
endmodule