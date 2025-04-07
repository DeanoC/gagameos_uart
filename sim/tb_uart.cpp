#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vtb_uart_all.h" // Include the top-level testbench module

// Simulation time
#define MAX_SIM_TIME 2000000
vluint64_t sim_time = 0;

// VCD tracing
#define VCD_PATH "tb_uart_all.vcd"

int main(int argc, char** argv) {
    // Initialize Verilator
    Verilated::commandArgs(argc, argv);
    
    // Create top-level instance
    Vtb_uart_all* tb_uart_all = new Vtb_uart_all;
    
    // Initialize VCD tracing
    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    tb_uart_all->trace(tfp, 99);
    tfp->open(VCD_PATH);
    
    // Initialize signals
    tb_uart_all->clk = 0;
    tb_uart_all->rst_n = 0;
    
    // Run initial cycles with reset
    for (int i = 0; i < 10; i++) {
        tb_uart_all->clk = !tb_uart_all->clk;
        tb_uart_all->eval();
        tfp->dump(sim_time++);
    }
    
    // Release reset
    tb_uart_all->rst_n = 1;
    
    // Run simulation
    while (sim_time < MAX_SIM_TIME) {
        tb_uart_all->clk = !tb_uart_all->clk;
        tb_uart_all->eval();
        tfp->dump(sim_time++);
    }
    
    // Clean up
    tb_uart_all->final();
    tfp->close();
    delete tfp;
    delete tb_uart_all;
    
    std::cout << "Simulation completed after " << std::dec << sim_time << " ticks" << std::endl;
    return 0;
}