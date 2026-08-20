# Template Makefile for a new core under digital-soc-engineering/src/.
# Copy this whole file into the new core's directory (e.g.
# src/pillar-1/spi-controller/Makefile) and fill in the two spots marked
# below. No .vscode/ needed alongside it -- the root-level
# digital-soc-engineering/.vscode/tasks.json already lints any core
# automatically on save by walking up from whichever file changed to
# find its nearest Makefile.

PROJECT_ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Packages must precede the modules that import them.
RTL ?= rtl/<core>_pkg.sv rtl/<core>_top.sv  # <-- fill in for this core
TB_PKG ?=
TB ?=
TOP ?=

# Set to this core's package file once it has one (e.g. rtl/spi_pkg.sv)
# -- lint-all puts it first automatically. Leave empty if there's no
# package yet.
PKG ?=  # <-- fill in for this core

TOOL ?= verilator
SIM_TOOL ?= $(TOOL)
VERILATOR ?= verilator
IVERILOG ?= iverilog
BUILD_DIR ?= sim_build
LINT_FLAGS ?=
SIM_FLAGS ?=
WAVEFILE ?= sim/waveforms/wave.fst
WAVEFILE_VCD ?= sim/waveforms/wave.vcd
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

.PHONY: help lint lint-all sim wave e2e coverage clean

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
lint-all:
	$(MAKE) lint RTL="$(PKG) $(shell find $(PROJECT_ROOT)rtl -name '*.sv' $(if $(PKG),! -name '$(notdir $(PKG))',) | sed 's|$(PROJECT_ROOT)||' | sort)"

sim:
	$(SIM_CMD)

wave:
	$(WAVE_VIEWER) $(WAVE_TARGET)

coverage:
	$(COVERAGE_CMD)

e2e: lint sim wave coverage

clean:
	rm -rf obj_dir $(BUILD_DIR) sim/waveforms/*.fst sim/waveforms/*.vcd $(COVERAGE_DIR)
