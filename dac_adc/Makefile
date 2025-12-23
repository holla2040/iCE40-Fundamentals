# Makefile for iCE40 HX1K
# Open-source toolchain: yosys + nextpnr + icestorm

PROJECT = adc_sweep
SOURCES = top.v

# iCE40 HX1K in VQ100 package
DEVICE = hx1k
PACKAGE = vq100

# Build all
all: $(PROJECT).bin

# Synthesize
$(PROJECT).json: $(SOURCES)
	yosys -p "synth_ice40 -top top -json $@" $(SOURCES)

# Place and route
$(PROJECT).asc: $(PROJECT).json pins.pcf
	nextpnr-ice40 --$(DEVICE) --package $(PACKAGE) --json $< --pcf pins.pcf --asc $@

# Generate bitstream
$(PROJECT).bin: $(PROJECT).asc
	icepack $< $@

# Program FPGA
prog: $(PROJECT).bin
	iceprog $<

# Show timing report
timing: $(PROJECT).asc
	icetime -d $(DEVICE) -r timing.rpt $<
	cat timing.rpt

# Clean
clean:
	rm -f $(PROJECT).json $(PROJECT).asc $(PROJECT).bin timing.rpt

.PHONY: all prog timing clean
