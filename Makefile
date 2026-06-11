# ==============================
# SmartBFT TLA+ Makefile
# ==============================

# Main TLA+ spec file
SPEC = SmartBFT.tla

# TLC jar location
TLC = tla2tools.jar

# Default config file
CFG ?= configs/SmartBFT_tiny.cfg

# Output folders
OUT_DIR = outputs
GRAPH_DIR = graphs
META_DIR = .tlc-meta
STATES_DIR = states
REPORT_DIR = reports

# Extract config basename without folder and extension
CFG_NAME = $(basename $(notdir $(CFG)))

REPORT_FILE = $(REPORT_DIR)/$(CFG_NAME).html

# Output files
OUT_FILE = $(OUT_DIR)/$(CFG_NAME).out
DOT_FILE = $(GRAPH_DIR)/$(CFG_NAME).dot
SVG_FILE = $(GRAPH_DIR)/$(CFG_NAME).svg
PNG_FILE = $(GRAPH_DIR)/$(CFG_NAME).png

# Default TLC options
TLC_OPTS ?= -workers auto -metadir $(META_DIR) -config $(CFG) $(SPEC) #This option runs without coverage
# TLC_OPTS ?= -workers auto -coverage 1 -metadir $(META_DIR) -config $(CFG) $(SPEC) #This option runs with coverage

.PHONY: help check graph svg png clean all-configs setup

help:
	@echo "SmartBFT TLA+ Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make check CFG=configs/SmartBFT_tiny.cfg"
	@echo "  make graph CFG=configs/SmartBFT_tiny.cfg"
	@echo "  make svg CFG=configs/SmartBFT_tiny.cfg"
	@echo "  make png CFG=configs/SmartBFT_tiny.cfg"
	@echo "  make all-configs"
	@echo "  make clean"
	@echo ""
	@echo "Variables:"
	@echo "  CFG       Config file to use"
	@echo "  TLC_OPTS  Extra TLC options"
	@echo ""
	@echo "Examples:"
	@echo "  make check CFG=configs/SmartBFT_faulty_leader.cfg"
	@echo "  make svg CFG=configs/SmartBFT_tiny.cfg"
	@echo "  make check CFG=configs/SmartBFT_tiny.cfg TLC_OPTS='-workers auto -coverage 1'"

setup:
	@mkdir -p $(OUT_DIR)
	@mkdir -p $(GRAPH_DIR)
	@mkdir -p $(META_DIR)

check: setup
	@echo "Running TLC..."
	@echo "Spec:   $(SPEC)"
	@echo "Config: $(CFG)"
	@echo "TLC_OPTS: $(TLC_OPTS)"
	@echo "Output: $(OUT_FILE)"
	java -jar $(TLC) $(TLC_OPTS) | tee $(OUT_FILE)
	python3 scripts/parse_tlc_out.py $(OUT_FILE) $(REPORT_FILE)

graph: setup
	@echo "Generating DOT graph..."
	@echo "Spec:   $(SPEC)"
	@echo "Config: $(CFG)"
	@echo "TLC_OPTS: $(TLC_OPTS)"
	@echo "DOT:    $(DOT_FILE)"
	java -jar $(TLC) $(TLC_OPTS) -dump dot,actionlabels,colorize $(DOT_FILE) | tee $(OUT_FILE)
	

svg: graph
	@echo "Converting DOT to SVG..."
	dot -Tsvg $(DOT_FILE) -o $(SVG_FILE)
	@echo "SVG written to $(SVG_FILE)"
	python3 scripts/parse_tlc_out.py $(OUT_FILE) $(REPORT_FILE) $(SVG_FILE)

png: graph
	@echo "Converting DOT to PNG..."
	dot -Tpng $(DOT_FILE) -o $(PNG_FILE)
	@echo "PNG written to $(PNG_FILE)"
	python3 scripts/parse_tlc_out.py $(OUT_FILE) $(REPORT_FILE) $(PNG_FILE)

clean:
	rm -rf $(OUT_DIR)
	rm -rf $(GRAPH_DIR)
	rm -rf $(STATES_DIR)
	rm -rf $(META_DIR)
	rm -rf $(REPORT_DIR)