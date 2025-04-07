// Top-level testbench to run all UART-related tests
`timescale 1ns/1ps

module tb_uart_all;

    // Instantiate tb_uart_tx
    tb_uart_tx tb_uart_tx_inst();

    // Instantiate tb_uart_top
    tb_uart_top tb_uart_top_inst();

    // Instantiate tb_uart_baud_gen
    tb_uart_baud_gen tb_uart_baud_gen_inst();

    // Instantiate tb_uart_fifo
    tb_uart_fifo tb_uart_fifo_inst();

    // Simulation control
    initial begin
        $display("Starting all UART tests...");
        
        // Run tb_uart_tx
        $display("Running tb_uart_tx...");
        repeat (1000) @(posedge tb_uart_tx_inst.clk); // Replace #1000 with repeat construct

        // Run tb_uart_top
        $display("Running tb_uart_top...");
        repeat (1000) @(posedge tb_uart_top_inst.clk); // Replace #1000 with repeat construct

        // Run tb_uart_baud_gen
        $display("Running tb_uart_baud_gen...");
        repeat (1000) @(posedge tb_uart_baud_gen_inst.clk); // Replace #1000 with repeat construct

        // Run tb_uart_fifo
        $display("Running tb_uart_fifo...");
        repeat (1000) @(posedge tb_uart_fifo_inst.clk); // Replace #1000 with repeat construct

        $display("All UART tests completed.");
        $finish;
    end

    // Dump waveforms
    initial begin
        $dumpfile("tb_uart_all.vcd");
        $dumpvars(0, tb_uart_all);
    end

endmodule
