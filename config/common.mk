# Shared Makefile for iCE40 HX1K projects
DEVICE = hx1k
PACKAGE = vq100

# Defaults (can be overridden in project Makefile)
SRCS ?= $(PROJ).v
PCF ?= pins.pcf
TOP ?= top
DEPS ?=

# Build output directory
BUILDDIR = /tmp/build/$(PROJ)

# Build outputs (in temp directory)
JSON = $(BUILDDIR)/$(PROJ).json
ASC = $(BUILDDIR)/$(PROJ).asc
BIN = $(BUILDDIR)/$(PROJ).bin

.PHONY: all flash clean

all: $(BIN)

$(BUILDDIR):
	mkdir -p $@

$(JSON): $(SRCS) $(DEPS) | $(BUILDDIR)
	yosys -q -p "read_verilog $(SRCS); synth_ice40 -top $(TOP) -json $@"

$(ASC): $(JSON) $(PCF) | $(BUILDDIR)
	nextpnr-ice40 -q --$(DEVICE) --package $(PACKAGE) --json $< --pcf $(PCF) --asc $@

$(BIN): $(ASC)
	icepack $< $@

flash: $(BIN)
	iceprog $<

clean:
	rm -rf $(BUILDDIR)
