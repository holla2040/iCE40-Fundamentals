# Shared Makefile for iCE40 HX1K projects
DEVICE = hx1k
PACKAGE = vq100

# Defaults (can be overridden in project Makefile)
SRCS ?= $(PROJ).v
PCF ?= pins.pcf
TOP ?= top
DEPS ?=

# Build outputs
JSON = $(PROJ).json
ASC = $(PROJ).asc
BIN = $(PROJ).bin

.PHONY: all flash clean

all: $(BIN)

$(JSON): $(SRCS) $(DEPS)
	yosys -q -p "read_verilog $(SRCS); synth_ice40 -top $(TOP) -json $@"

$(ASC): $(JSON) $(PCF)
	nextpnr-ice40 -q --$(DEVICE) --package $(PACKAGE) --json $< --pcf $(PCF) --asc $@

$(BIN): $(ASC)
	icepack $< $@

flash: $(BIN)
	iceprog $<

clean:
	rm -f $(JSON) $(ASC) $(BIN)
