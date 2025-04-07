#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vuart_top.h"

// Simulation time
#define MAX_SIM_TIME 1000000
vluint64_t sim_time = 0;

// VCD tracing
#define VCD_PATH "uart_sim.vcd"

int main(int argc, char** argv) {
    // Initialize Verilator
    Verilated::commandArgs(argc, argv);
    
    // Create top-level instance
    Vuart_top* uart = new Vuart_top;
    
    // Initialize VCD tracing
    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    uart->trace(tfp, 99);
    tfp->open(VCD_PATH);
    
    // Initialize signals
    uart->clk = 0;
    uart->rst_n = 0;
    uart->rx = 1;      // Idle state for UART
    uart->addr = 0;
    uart->wdata = 0;
    uart->wr_en = 0;
    uart->rd_en = 0;
    
    // Run initial cycles with reset
    for (int i = 0; i < 10; i++) {
        uart->clk = !uart->clk;
        uart->eval();
        tfp->dump(sim_time++);
    }
    
    // Release reset
    uart->rst_n = 1;
    
    // Initialize UART via MMIO
    // Set baud rate divisor (for example to achieve 115200 from 50MHz)
    uart->clk = !uart->clk; uart->eval(); tfp->dump(sim_time++);
    uart->clk = !uart->clk; uart->eval(); tfp->dump(sim_time++);
    
    uart->addr = 0x2;  // BAUD_DIV register
    uart->wdata = 27;  // 50MHz / 115200 / 16 ≈ 27
    uart->wr_en = 1;
    uart->clk = !uart->clk; uart->eval(); tfp->dump(sim_time++);
    uart->clk = !uart->clk; uart->eval(); tfp->dump(sim_time++);
    uart->wr_en = 0;
    
    // Enable UART
    uart->addr = 0x0;  // CTRL register
    uart->wdata = 0x1; // Enable bit
    uart->wr_en = 1;
    uart->clk = !uart->clk; uart->eval(); tfp->dump(sim_time++);
    uart->clk = !uart->clk; uart->eval(); tfp->dump(sim_time++);
    uart->wr_en = 0;
    
    // Write data to TX FIFO
    uart->addr = 0x3;  // TX_DATA register
    uart->wdata = 0x55; // Example data ('U')
    uart->wr_en = 1;
    uart->clk = !uart->clk; uart->eval(); tfp->dump(sim_time++);
    uart->clk = !uart->clk; uart->eval(); tfp->dump(sim_time++);
    uart->wr_en = 0;
    
    // Run simulation for a while
    std::cout << "Starting UART simulation..." << std::endl;
    
    while (sim_time < MAX_SIM_TIME) {
        uart->clk = !uart->clk;
        uart->eval();
        tfp->dump(sim_time);
        
        // Check status periodically
        if (sim_time % 100000 == 0) {
            uart->addr = 0x1; // STATUS register
            uart->rd_en = 1;
            uart->clk = !uart->clk; uart->eval(); tfp->dump(sim_time++);
            uart->clk = !uart->clk; uart->eval(); tfp->dump(sim_time++);
            uart->rd_en = 0;
            
            std::cout << "Simulation time: " << sim_time 
                      << ", Status: 0x" << std::hex << uart->rdata << std::endl;
        }
        
        sim_time++;
    }
    
    // Clean up
    uart->final();
    tfp->close();
    delete tfp;
    delete uart;
    
    std::cout << "Simulation completed after " << sim_time << " ticks" << std::endl;
    return 0;
}