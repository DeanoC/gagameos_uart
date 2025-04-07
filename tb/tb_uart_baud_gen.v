// Testbench for UART baud rate generator
`timescale 1ns/1ps

module tb_uart_baud_gen;
    // Testbench signals
    reg clk;
    reg rst_n;
    reg enable;
    reg [15:0] divisor;
    wire tick;
    
    // Counters for verification
    integer tick_count;
    integer cycle_count;
    integer test_count;
    
    // Clock period definitions
    localparam CLK_PERIOD = 20; // 50MHz clock
    
    // Instantiate the Unit Under Test (UUT)
    uart_baud_gen uut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .divisor(divisor),
        .tick(tick)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Test procedure
    initial begin
        // Initialize signals
        rst_n = 0;
        enable = 0;
        divisor = 16'd27; // For 115200 baud @ 50MHz with 16x oversample
        tick_count = 0;
        cycle_count = 0;
        test_count = 0;
        
        // Reset sequence
        #(CLK_PERIOD*5);
        rst_n = 1;
        #(CLK_PERIOD*2);
        
        // Test case 1: Verify disabled state
        $display("Test %0d: Verify disabled state", test_count);
        enable = 0;
        #(CLK_PERIOD*100);
        if (tick_count == 0) 
            $display("PASS: No ticks generated when disabled");
        else 
            $display("FAIL: %0d ticks generated when disabled", tick_count);
        test_count++;
        
        // Test case 2: Verify divisor = 4 (expecting tick every 4 cycles)
        $display("Test %0d: Verify divisor = 4", test_count);
        tick_count = 0;
        cycle_count = 0;
        divisor = 16'd4;
        enable = 1;
        #(CLK_PERIOD*50); // Run for 50 cycles
        if (tick_count == 12) // Expecting about 50/4 = 12 ticks
            $display("PASS: Generated %0d ticks with divisor = 4", tick_count);
        else
            $display("FAIL: Generated %0d ticks with divisor = 4, expected about 12", tick_count);
        test_count++;
        
        // Test case 3: Verify divisor = 10 (expecting tick every 10 cycles)
        $display("Test %0d: Verify divisor = 10", test_count);
        tick_count = 0;
        cycle_count = 0;
        divisor = 16'd10;
        #(CLK_PERIOD*100); // Run for 100 cycles
        if (tick_count == 10) // Expecting about 100/10 = 10 ticks
            $display("PASS: Generated %0d ticks with divisor = 10", tick_count);
        else
            $display("FAIL: Generated %0d ticks with divisor = 10, expected about 10", tick_count);
        test_count++;
        
        // Test case 4: Verify disabling stops ticks
        $display("Test %0d: Verify disabling stops ticks", test_count);
        tick_count = 0;
        enable = 0;
        #(CLK_PERIOD*50);
        if (tick_count == 0)
            $display("PASS: No ticks generated after disabling");
        else
            $display("FAIL: %0d ticks generated after disabling", tick_count);
        test_count++;
        
        // Test case 5: Verify re-enabling restarts ticks
        $display("Test %0d: Verify re-enabling restarts ticks", test_count);
        tick_count = 0;
        enable = 1;
        #(CLK_PERIOD*50);
        if (tick_count > 0)
            $display("PASS: %0d ticks generated after re-enabling", tick_count);
        else
            $display("FAIL: No ticks generated after re-enabling");
        test_count++;
        
        // Finish simulation
        $display("All tests completed");
        $finish;
    end
    
    // Monitor for tick assertions
    always @(posedge clk) begin
        if (tick) tick_count = tick_count + 1;
        cycle_count = cycle_count + 1;
    end
    
    // Dump waveforms
    initial begin
        $dumpfile("tb_uart_baud_gen.vcd");
        $dumpvars(0, tb_uart_baud_gen);
    end
    
endmodule