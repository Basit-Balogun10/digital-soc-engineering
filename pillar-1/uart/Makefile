PROJECT_ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Packages must precede the modules that import them.
RTL ?= rtl/mmio_register_bank.sv
TB_PK ?= 
TB ?= 
TOP ?=

# RTL ?= rtl/uart_pkg.sv \
#        rtl/tx_core/tx_pkg.sv \
#        rtl/rx_core/rx_pkg.sv \
#        rtl/baud_generator.sv \
#        rtl/mmio_register_bank.sv \
#        rtl/uart_top.sv
# TB_PKG ?= tb/sv/tb_pkg.sv
# TB ?= tb/sv/tb_uart.sv
# TOP ?= tb_uart

PKG ?= rtl/uart_pkg.sv

TOOL ?= verilator
SIM_TOOL ?= $(TOOL)
VERILATOR ?= verilator
IVERILOG ?= iverilog
BUILD_DIR ?= sim_build
LINT_FLAGS ?=
SIM_FLAGS ?=
WAVEFILE ?= sim/waveforms/uart.fst
WAVEFILE_VCD ?= sim/waveforms/uart.vcd
COVERAGE_DIR ?= sim/coverage
COVERAGE_FILE ?= $(COVERAGE_DIR)/coverage.dat
COVERAGE_REPORT_DIR ?= $(COVERAGE_DIR)/annotated
WAVE_VIEWER ?= code

# --assert matters the instant real SVA lands in the TB: Verilator silently
# never evaluates assert property without it, giving a vacuous "clean" pass.
VERILATOR_LINT_FLAGS ?= --lint-only --sv -Wall -I$(PROJECT_ROOT)tb/sv
VERILATOR_SIM_FLAGS ?= --binary --sv --timing --assert --trace-fst --coverage -Wall -j 0 --top $(TOP) -I$(PROJECT_ROOT)tb/sv
IVERILOG_LINT_FLAGS ?= -g2012 -Wall -I$(PROJECT_ROOT)tb/sv
IVERILOG_SIM_FLAGS ?= -g2012 -Wall -I$(PROJECT_ROOT)tb/sv

ifeq ($(SIM_TOOL),verilator)
LINT_CMD = $(VERILATOR) $(VERILATOR_LINT_FLAGS) $(LINT_FLAGS) \
    $(addprefix $(PROJECT_ROOT),$(RTL)) \
    $(addprefix $(PROJECT_ROOT),$(TB_PKG)) \
    $(addprefix $(PROJECT_ROOT),$(TB))
SIM_CMD = cd $(PROJECT_ROOT) && mkdir -p $(dir $(WAVEFILE)) $(COVERAGE_DIR) && $(VERILATOR) $(VERILATOR_SIM_FLAGS) $(SIM_FLAGS) $(RTL) $(TB_PKG) $(TB) && ./obj_dir/V$(TOP) +verilator+seed+$(shell date +%s) +verilator+coverage+file+$(COVERAGE_FILE)
COVERAGE_CMD = cd $(PROJECT_ROOT) && test -f $(COVERAGE_FILE) || { echo "Missing $(COVERAGE_FILE); run 'make sim' with SIM_TOOL=verilator first."; exit 1; } && mkdir -p $(COVERAGE_REPORT_DIR) && verilator_coverage --annotate $(COVERAGE_REPORT_DIR)/ $(COVERAGE_FILE)
WAVE_TARGET := $(WAVEFILE)
else ifeq ($(SIM_TOOL),iverilog)
LINT_CMD = $(IVERILOG) $(IVERILOG_LINT_FLAGS) $(LINT_FLAGS) -t null \
    $(addprefix $(PROJECT_ROOT),$(RTL)) \
    $(addprefix $(PROJECT_ROOT),$(TB_PKG)) \
    $(addprefix $(PROJECT_ROOT),$(TB))
SIM_CMD = cd $(PROJECT_ROOT) && mkdir -p $(BUILD_DIR) $(dir $(WAVEFILE_VCD)) && $(IVERILOG) $(IVERILOG_SIM_FLAGS) $(SIM_FLAGS) -DWAVE_VCD -o $(BUILD_DIR)/$(TOP).vvp $(RTL) $(TB_PKG) $(TB) && vvp $(BUILD_DIR)/$(TOP).vvp +seed+$(shell date +%s)
COVERAGE_CMD = @echo "Coverage automation requires SIM_TOOL=verilator." && exit 1
WAVE_TARGET := $(WAVEFILE_VCD)
else
$(error Unsupported SIM_TOOL '$(SIM_TOOL)'. Use verilator or iverilog)
endif

.DEFAULT_GOAL := help

.PHONY: help lint sim wave e2e coverage clean

help:
	@echo "Targets:"
	@echo "  make help     - show this help"
	@echo "  make lint     - syntax/lint check \$$(RTL) only"
	@echo "  make lint-all - lint every .sv file under rtl/ together (catches cross-file issues)"
	@echo "  make sim      - build and run the selected simulator"
	@echo "  make wave     - open the waveform in VS Code"
	@echo "  make coverage - annotate Verilator coverage into sim/coverage/annotated"
	@echo "  make e2e      - run lint, sim, wave, then coverage"
	@echo "  make clean    - remove generated simulation artifacts"
	@echo ""
	@echo "Options:"
	@echo "  TOOL=verilator|iverilog      - select the simulator toolchain"
	@echo "  SIM_TOOL=verilator|iverilog  - alias for TOOL"
	@echo "  LINT_FLAGS=...               - extra flags appended to lint"
	@echo "  SIM_FLAGS=...                - extra flags appended to sim"
	@echo "  WAVE_VIEWER=code|...         - waveform viewer command"
	@echo ""
	@echo "Examples:"
	@echo "  make lint"
	@echo "  make lint SIM_TOOL=iverilog"
	@echo "  make sim TOOL=iverilog"
	@echo "  make wave WAVE_VIEWER=code"
	@echo "  make e2e SIM_TOOL=verilator"
	@echo "  make coverage SIM_TOOL=verilator"

lint:
	$(LINT_CMD)

# Lints every .sv file under rtl/ together (not just $(RTL)'s single-file
# default), so real cross-file issues -- a missing package, a mismatched
# import -- actually surface, instead of being masked by linting each
# file in isolation. $(PKG) goes first since packages must precede the
# modules that import them. Picks up new files automatically as they're
# added -- no per-file list to hand-maintain.
#
# -Wno-MULTITOP: expected right now, bottom-up, before uart_top.sv wires
# components together -- each finished component (mmio_register_bank,
# fifo, ...) is a genuinely independent top until something instantiates
# it. Remove this suppression once uart_top.sv is real: from then on, an
# unexpected extra top is worth catching again, not silencing.
lint-all:
	$(MAKE) lint LINT_FLAGS="-Wno-MULTITOP" RTL="$(PKG) $(shell find $(PROJECT_ROOT)rtl -name '*.sv' $(if $(PKG),! -name '$(notdir $(PKG))',) | sed 's|$(PROJECT_ROOT)||' | sort)"

sim:
	$(SIM_CMD)

wave:
	$(WAVE_VIEWER) $(WAVE_TARGET)

coverage:
	$(COVERAGE_CMD)

e2e: lint sim wave coverage

clean:
	rm -rf obj_dir $(BUILD_DIR) sim/waveforms/*.fst sim/waveforms/*.vcd $(COVERAGE_DIR)
