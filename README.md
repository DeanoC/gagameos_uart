# GagaMEOS UART

A parameterized UART (Universal Asynchronous Receiver/Transmitter) implementation in Verilog with the following features:

- Variable input clock support for multi-board compatibility
- Support for common baud rates up to a few megabaud (3Mbps)
- 8N1 format (8 data bits, no parity, 1 stop bit)
- Memory-mapped I/O (MMIO) interface for CPU interaction
- Parameterized FIFOs for TX and RX buffers
- Verilator support for simulation and testing

## Architecture

The UART consists of several modules:

- `uart_top`: Top-level module connecting all components
- `uart_tx`: Transmitter logic
- `uart_rx`: Receiver logic with oversampling
- `uart_baud_gen`: Baud rate generator with programmable divider
- `uart_fifo`: Parameterized FIFO implementation for TX/RX buffers
- `uart_regs`: Register file for MMIO interface

## MMIO Register Map

| Offset | Register Name | Description |
|--------|--------------|-------------|
| 0x00   | CTRL         | Control register (enable, reset FIFOs) |
| 0x04   | STATUS       | Status register (FIFO levels, errors) |
| 0x08   | BAUD_DIV     | Baud rate divisor |
| 0x0C   | TX_DATA      | TX FIFO write port |
| 0x10   | RX_DATA      | RX FIFO read port |
| 0x14   | INT_ENABLE   | Interrupt enable bits |
| 0x18   | INT_STATUS   | Interrupt status bits |

## Baud Rate Calculation

The baud rate is determined by the formula:
```
Divisor = (Clock Frequency) / (Baud Rate × Oversampling Factor)
```

For example, for 115200 baud with a 50MHz clock and 16x oversampling:
```
Divisor = 50,000,000 / (115,200 × 16) ≈ 27.1267
```

The divisor is rounded to the nearest integer: 27.

## Build and Test

### Prerequisites

- Verilator (for simulation)
- Icarus Verilog (for testbenches)
- Make

### Running Tests

To run the Verilator simulation:
```
make sim
```

To test a specific module (e.g., UART TX):
```
make test_uart_tx
```

To run lint check on all Verilog code:
```
make lint
```

## License

MIT License