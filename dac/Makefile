# Makefile for DAC project (iCE40HX1K-VQ100)
# DAC121S101 12-bit SPI DAC

PROJ = dac_top
DEVICE = hx1k
PACKAGE = vq100
PCF = pins.pcf

all: $(PROJ).bin

# Synthesis (Verilog -> JSON)
$(PROJ).json: $(PROJ).v ramp.mem
	@echo "Synthesizing..."
	@yosys -q -p "synth_ice40 -top top -json $@" $(PROJ).v

# Place and Route
$(PROJ).asc: $(PROJ).json $(PCF)
	@echo "Place and route..."
	@nextpnr-ice40 -q --$(DEVICE) --package $(PACKAGE) --json $< --pcf $(PCF) --asc $@

# Bitstream generation
$(PROJ).bin: $(PROJ).asc
	@echo "Generating bitstream..."
	@icepack $< $@

# Flash the board
flash: $(PROJ).bin
	@echo "Flashing..."
	@iceprog $<

# Clean build artifacts
clean:
	rm -f $(PROJ).json $(PROJ).asc $(PROJ).bin

.PHONY: all flash clean
