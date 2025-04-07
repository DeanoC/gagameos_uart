// Testbench for UART FIFO
`timescale 1ns/1ps

module tb_uart_fifo;
    // Parameters
    parameter WIDTH = 8;
    parameter DEPTH = 16;
    parameter ADDR_WIDTH = $clog2(DEPTH);
    
    // Testbench signals
    reg clk;
    reg rst_n;
    reg write_en;
    reg read_en;
    reg [WIDTH-1:0] data_in;
    wire [WIDTH-1:0] data_out;
    wire empty;
    wire full;
    wire [ADDR_WIDTH:0] level;
    reg [ADDR_WIDTH:0] threshold;
    wire threshold_reached;
    
    // Test variables
    integer i;
    integer test_count;
    reg [WIDTH-1:0] read_data;
    reg pass;
    
    // Clock period definitions
    localparam CLK_PERIOD = 20; // 50MHz clock
    
    // Instantiate the Unit Under Test (UUT)
    uart_fifo #(
        .DEPTH(DEPTH),
        .WIDTH(WIDTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .write_en(write_en),
        .read_en(read_en),
        .data_in(data_in),
        .data_out(data_out),
        .empty(empty),
        .full(full),
        .level(level),
        .threshold(threshold),
        .threshold_reached(threshold_reached)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever begin
            repeat (CLK_PERIOD / 2) @(posedge clk);
            clk = ~clk;
        end
    end
    
    // Test procedure
    initial begin
        // Initialize signals
        rst_n = 0;
        write_en = 0;
        read_en = 0;
        data_in = 0;
        threshold = 8;
        test_count = 0;
        pass = 1;
        
        // Reset sequence
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);
        
        // Test case 1: Verify initial empty state
        $display("Test %0d: Verify initial empty state", test_count);
        if (empty && !full && level == 0) 
            $display("PASS: FIFO is initially empty");
        else
            $display("FAIL: FIFO not in expected initial state. empty=%0b, full=%0b, level=%0d", 
                     empty, full, level);
        test_count++;
        
        // Test case 2: Write one value and read it back
        $display("Test %0d: Write one value and read it back", test_count);
        data_in = 8'hA5;
        write_en = 1;
        @(posedge clk);
        write_en = 0;
        
        if (!empty && level == 1) 
            $display("PASS: FIFO has one item");
        else
            $display("FAIL: FIFO should have one item. empty=%0b, level=%0d", empty, level);
        
        read_en = 1;
        @(posedge clk);
        read_en = 0;
        
        if (data_out === 8'hA5) 
            $display("PASS: Read correct data 0xA5");
        else
            $display("FAIL: Read incorrect data. Expected 0xA5, got 0x%0h", data_out);
        
        if (empty && level == 0)
            $display("PASS: FIFO is empty after read");
        else
            $display("FAIL: FIFO should be empty after read. empty=%0b, level=%0d", empty, level);
        test_count++;
        
        // Test case 3: Fill FIFO to capacity
        $display("Test %0d: Fill FIFO to capacity", test_count);
        for (i = 0; i < DEPTH; i = i + 1) begin
            data_in = i[WIDTH-1:0]; // Ensure width matches
            write_en = 1;
            @(posedge clk);
        end
        write_en = 0;
        
        if (full && level == DEPTH)
            $display("PASS: FIFO is full");
        else
            $display("FAIL: FIFO should be full. full=%0b, level=%0d", full, level);
        test_count++;
        
        // Test case 4: Attempt to write when full
        $display("Test %0d: Attempt to write when full", test_count);
        data_in = 8'hFF;
        write_en = 1;
        @(posedge clk);
        write_en = 0;
        
        if (level == DEPTH)
            $display("PASS: FIFO level unchanged after write to full FIFO");
        else
            $display("FAIL: FIFO level changed after write to full FIFO. level=%0d", level);
        test_count++;
        
        // Test case 5: Read all values from full FIFO
        $display("Test %0d: Read all values from full FIFO", test_count);
        pass = 1;
        for (i = 0; i < DEPTH; i = i + 1) begin
            read_en = 1;
            @(posedge clk);
            if (data_out !== i[WIDTH-1:0]) begin // Ensure width matches
                $display("FAIL: Read incorrect data at position %0d. Expected 0x%0h, got 0x%0h", 
                         i, i[WIDTH-1:0], data_out);
                pass = 0;
            end
        end
        read_en = 0;
        
        if (pass)
            $display("PASS: All data read correctly from FIFO");
        
        if (empty && level == 0)
            $display("PASS: FIFO is empty after reading all items");
        else
            $display("FAIL: FIFO should be empty. empty=%0b, level=%0d", empty, level);
        test_count++;
        
        // Test case 6: Attempt to read when empty
        $display("Test %0d: Attempt to read when empty", test_count);
        read_data = data_out;
        read_en = 1;
        @(posedge clk);
        read_en = 0;
        
        if (data_out === read_data)
            $display("PASS: Data unchanged after read from empty FIFO");
        else
            $display("FAIL: Data changed after read from empty FIFO");
        test_count++;
        
        // Test case 7: Verify threshold functionality
        $display("Test %0d: Verify threshold functionality", test_count);
        threshold = 4;
        
        for (i = 0; i < 3; i = i + 1) begin
            data_in = i;
            write_en = 1;
            @(posedge clk);
        end
        write_en = 0;
        
        if (!threshold_reached)
            $display("PASS: Threshold not reached with 3 items and threshold=4");
        else
            $display("FAIL: Threshold incorrectly reached with level=%0d and threshold=%0d", 
                     level, threshold);
        
        data_in = 8'hAA;
        write_en = 1;
        @(posedge clk);
        write_en = 0;
        
        if (threshold_reached)
            $display("PASS: Threshold reached with 4 items and threshold=4");
        else
            $display("FAIL: Threshold not reached with level=%0d and threshold=%0d", 
                     level, threshold);
        
        // Empty the FIFO
        for (i = 0; i < 4; i = i + 1) begin
            read_en = 1;
            @(posedge clk);
        end
        read_en = 0;
        test_count++;
        
        // Test case 8: Write-read interleaving
        $display("Test %0d: Write-read interleaving", test_count);
        pass = 1;
        for (i = 0; i < 32; i = i + 1) begin
            // Write
            data_in = i;
            write_en = 1;
            @(posedge clk);
            write_en = 0;
            
            // Read
            read_en = 1;
            @(posedge clk);
            read_en = 0;
            
            if (data_out !== i) begin
                $display("FAIL: Interleaved write-read failed at iteration %0d. Expected 0x%0h, got 0x%0h", 
                         i, i, data_out);
                pass = 0;
            end
        end
        
        if (pass)
            $display("PASS: Interleaved write-read successful for 32 iterations");
        
        if (empty && level == 0)
            $display("PASS: FIFO is empty after interleaved operations");
        else
            $display("FAIL: FIFO should be empty. empty=%0b, level=%0d", empty, level);
        test_count++;
        
        // Finish simulation
        $display("All tests completed");
        $finish;
    end
    
    // Dump waveforms
    initial begin
        $dumpfile("tb_uart_fifo.vcd");
        $dumpvars(0, tb_uart_fifo);
    end
    
endmodule