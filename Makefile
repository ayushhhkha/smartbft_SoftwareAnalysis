# ==============================
# SmartBFT TLA+ Makefile
# ==============================

# Main TLA+ spec file
SPEC = SmartBFT.tla

# TLC jar location
TLC = tla2tools.jar

# Folders
CONFIG_DIR = configs
OUT_DIR = outputs
GRAPH_DIR = graphs
META_DIR = .tlc-meta
STATES_DIR = states
REPORT_DIR = reports

# Predefined configs
CFG_TINY             = $(CONFIG_DIR)/debug-2replicas-f0.cfg
CFG_NO_FAULTS        = $(CONFIG_DIR)/bft-f1-no-faults.cfg
CFG_F1_LEADER        = $(CONFIG_DIR)/bft-f1-faulty-leader.cfg
CFG_F1_NONLEADER     = $(CONFIG_DIR)/bft-f1-faulty-nonleader.cfg
CFG_F2_LEADER        = $(CONFIG_DIR)/bft-f2-faulty-leader.cfg
CFG_F2_NONLEADERS    = $(CONFIG_DIR)/bft-f2-faulty-nonleaders.cfg
CFG_F2_EXTRA         = $(CONFIG_DIR)/bft-f2-extra-replicas-faulty-nonleaders.cfg

CONFIGS = \
	$(CFG_TINY) \
	$(CFG_NO_FAULTS) \
	$(CFG_F1_LEADER) \
	$(CFG_F1_NONLEADER) \
	$(CFG_F2_LEADER) \
	$(CFG_F2_NONLEADERS) \
	$(CFG_F2_EXTRA)

# Default TLC options. Override from command line if needed, e.g.:
# make check-tiny TLC_BASE_OPTS="-workers 1 -coverage 1"
TLC_BASE_OPTS ?= -workers auto #-coverage 1

.PHONY: help setup clean all-configs \
	check-tiny check-no-faults check-f1-leader check-f1-nonleader \
	check-f2-leader check-f2-nonleaders check-f2-extra \
	graph-tiny graph-no-faults graph-f1-leader graph-f1-nonleader \
	graph-f2-leader graph-f2-nonleaders graph-f2-extra \
	svg-tiny svg-no-faults svg-f1-leader svg-f1-nonleader \
	svg-f2-leader svg-f2-nonleaders svg-f2-extra \
	png-tiny png-no-faults png-f1-leader png-f1-nonleader \
	png-f2-leader png-f2-nonleaders png-f2-extra

help:
	@echo "SmartBFT TLA+ Makefile"
	@echo ""
	@echo "Run TLC without manually passing CFG:"
	@echo "  make check-tiny"
	@echo "  make check-no-faults"
	@echo "  make check-f1-leader"
	@echo "  make check-f1-nonleader"
	@echo "  make check-f2-leader"
	@echo "  make check-f2-nonleaders"
	@echo "  make check-f2-extra"
	@echo ""
	@echo "Generate graphs:"
	@echo "  make graph-tiny"
	@echo "  make svg-tiny"
	@echo "  make png-tiny"
	@echo ""
	@echo "Other:"
	@echo "  make all-configs"
	@echo "  make clean"
	@echo ""
	@echo "Optional override:"
	@echo "  make check-tiny TLC_BASE_OPTS='-workers 1 -coverage 1'"

setup:
	@mkdir -p $(OUT_DIR) $(GRAPH_DIR) $(META_DIR) $(REPORT_DIR)

# $(call run_tlc, config-file)
define run_tlc
	@$(MAKE) --no-print-directory setup
	@cfg="$(1)"; \
	name=$$(basename $$cfg .cfg); \
	out="$(OUT_DIR)/$$name.out"; \
	report="$(REPORT_DIR)/$$name.html"; \
	echo "Running TLC..."; \
	echo "Spec:   $(SPEC)"; \
	echo "Config: $$cfg"; \
	echo "Output: $$out"; \
	java -jar $(TLC) $(TLC_BASE_OPTS) -metadir $(META_DIR) -config $$cfg $(SPEC) | tee $$out; \
	python3 scripts/parse_tlc_out.py $$out $$report
endef

# $(call run_graph, config-file)
define run_graph
	@$(MAKE) --no-print-directory setup
	@cfg="$(1)"; \
	name=$$(basename $$cfg .cfg); \
	out="$(OUT_DIR)/$$name.out"; \
	dotfile="$(GRAPH_DIR)/$$name.dot"; \
	echo "Generating DOT graph..."; \
	echo "Spec:   $(SPEC)"; \
	echo "Config: $$cfg"; \
	echo "DOT:    $$dotfile"; \
	java -jar $(TLC) $(TLC_BASE_OPTS) -metadir $(META_DIR) -config $$cfg $(SPEC) -dump dot,actionlabels,colorize $$dotfile | tee $$out
endef

# $(call run_svg, config-file)
define run_svg
	@$(MAKE) --no-print-directory graph-$(2)
	@name=$$(basename "$(1)" .cfg); \
	dotfile="$(GRAPH_DIR)/$$name.dot"; \
	svgfile="$(GRAPH_DIR)/$$name.svg"; \
	out="$(OUT_DIR)/$$name.out"; \
	report="$(REPORT_DIR)/$$name.html"; \
	echo "Converting DOT to SVG..."; \
	dot -Tsvg $$dotfile -o $$svgfile; \
	echo "SVG written to $$svgfile"; \
	python3 scripts/parse_tlc_out.py $$out $$report $$svgfile
endef

# $(call run_png, config-file)
define run_png
	@$(MAKE) --no-print-directory graph-$(2)
	@name=$$(basename "$(1)" .cfg); \
	dotfile="$(GRAPH_DIR)/$$name.dot"; \
	pngfile="$(GRAPH_DIR)/$$name.png"; \
	out="$(OUT_DIR)/$$name.out"; \
	report="$(REPORT_DIR)/$$name.html"; \
	echo "Converting DOT to PNG..."; \
	dot -Tpng $$dotfile -o $$pngfile; \
	echo "PNG written to $$pngfile"; \
	python3 scripts/parse_tlc_out.py $$out $$report $$pngfile
endef

check-tiny:
	$(call run_tlc,$(CFG_TINY))
check-no-faults:
	$(call run_tlc,$(CFG_NO_FAULTS))
check-f1-leader:
	$(call run_tlc,$(CFG_F1_LEADER))
check-f1-nonleader:
	$(call run_tlc,$(CFG_F1_NONLEADER))
check-f2-leader:
	$(call run_tlc,$(CFG_F2_LEADER))
check-f2-nonleaders:
	$(call run_tlc,$(CFG_F2_NONLEADERS))
check-f2-extra:
	$(call run_tlc,$(CFG_F2_EXTRA))

all-configs: check-tiny check-no-faults check-f1-leader check-f1-nonleader check-f2-leader check-f2-nonleaders check-f2-extra

graph-tiny:
	$(call run_graph,$(CFG_TINY))
graph-no-faults:
	$(call run_graph,$(CFG_NO_FAULTS))
graph-f1-leader:
	$(call run_graph,$(CFG_F1_LEADER))
graph-f1-nonleader:
	$(call run_graph,$(CFG_F1_NONLEADER))
graph-f2-leader:
	$(call run_graph,$(CFG_F2_LEADER))
graph-f2-nonleaders:
	$(call run_graph,$(CFG_F2_NONLEADERS))
graph-f2-extra:
	$(call run_graph,$(CFG_F2_EXTRA))

svg-tiny:
	$(call run_svg,$(CFG_TINY),tiny)
svg-no-faults:
	$(call run_svg,$(CFG_NO_FAULTS),no-faults)
svg-f1-leader:
	$(call run_svg,$(CFG_F1_LEADER),f1-leader)
svg-f1-nonleader:
	$(call run_svg,$(CFG_F1_NONLEADER),f1-nonleader)
svg-f2-leader:
	$(call run_svg,$(CFG_F2_LEADER),f2-leader)
svg-f2-nonleaders:
	$(call run_svg,$(CFG_F2_NONLEADERS),f2-nonleaders)
svg-f2-extra:
	$(call run_svg,$(CFG_F2_EXTRA),f2-extra)

png-tiny:
	$(call run_png,$(CFG_TINY),tiny)
png-no-faults:
	$(call run_png,$(CFG_NO_FAULTS),no-faults)
png-f1-leader:
	$(call run_png,$(CFG_F1_LEADER),f1-leader)
png-f1-nonleader:
	$(call run_png,$(CFG_F1_NONLEADER),f1-nonleader)
png-f2-leader:
	$(call run_png,$(CFG_F2_LEADER),f2-leader)
png-f2-nonleaders:
	$(call run_png,$(CFG_F2_NONLEADERS),f2-nonleaders)
png-f2-extra:
	$(call run_png,$(CFG_F2_EXTRA),f2-extra)

clean:
	rm -rf $(OUT_DIR) $(GRAPH_DIR) $(STATES_DIR) $(META_DIR) $(REPORT_DIR)