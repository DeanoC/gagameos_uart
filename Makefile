# Makefile for gagameos_uart Verilog project
# With Verilator support for simulation and validation

# Project structure
SRC_DIR = src
SIM_DIR = sim
TB_DIR = tb
BUILD_DIR = build
DOC_DIR = doc

# Source files
VERILOG_SOURCES = $(wildcard $(SRC_DIR)/*.v)
TB_SOURCES = $(wildcard $(TB_DIR)/*.v)

# Verilator configuration
VERILATOR = verilator
VERILATOR_FLAGS = --trace --trace-params --trace-structs --trace-underscore \
                 -Wno-fatal \
                 --x-assign unique --x-initial unique \
                 --assert \
                 -Wall -Werror-PINCONNECTEMPTY -Werror-IMPLICIT -Wno-DECLFILENAME \
                 -Wno-PINMISSING -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN

# Verilator C++ testbench
VERILATOR_CPP_TB = $(SIM_DIR)/tb_uart.cpp
VERILATOR_FLAGS += --cc --exe --build $(VERILATOR_CPP_TB)
VERILATOR_CONFIG = $(SIM_DIR)/verilator_config.vlt

# Default toplevel module
TOPLEVEL = uart_top

.PHONY: all clean sim verilate test lint help

# Default target
all: sim

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	rm -rf obj_dir
	rm -f *.vcd

# Verilator simulation
verilate: $(VERILOG_SOURCES) $(VERILATOR_CPP_TB)
	$(VERILATOR) $(VERILATOR_FLAGS) \
		-o $(BUILD_DIR)/V$(TOPLEVEL) \
		--top-module $(TOPLEVEL) \
		$(VERILOG_SOURCES) \
		-CFLAGS "-I$(SIM_DIR)"
	
sim: verilate
	./obj_dir/V$(TOPLEVEL)

# Testbench simulation with specific module
test_%: $(VERILOG_SOURCES) $(TB_DIR)/tb_%.v
	mkdir -p $(BUILD_DIR)
	iverilog -o $(BUILD_DIR)/$@ $(SRC_DIR)/$*.v $(TB_DIR)/tb_$*.v
	vvp $(BUILD_DIR)/$@
	
# Lint check
lint: $(VERILOG_SOURCES)
	$(VERILATOR) --lint-only -Wall $(VERILATOR_FLAGS) \
		--top-module $(TOPLEVEL) \
		$(VERILOG_SOURCES)

# Help target
help:
	@echo "Makefile for gagameos_uart Verilog project"
	@echo ""
	@echo "Targets:"
	@echo "  all      - Default target, build and run sim"
	@echo "  clean    - Remove build artifacts"
	@echo "  verilate - Compile Verilog with Verilator"
	@echo "  sim      - Run Verilator simulation"
	@echo "  test_X   - Run testbench for module X"
	@echo "  lint     - Run Verilator lint check"
	@echo ""
	@echo "Examples:"
	@echo "  make test_uart_tx   - Test the UART TX module"
	@echo "  make lint           - Lint check all Verilog code"