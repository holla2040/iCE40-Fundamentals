# Makefile for ADC project (iCE40HX1K-VQ100)
# AD7476A 12-bit SPI ADC

PROJ = adc_top
DEVICE = hx1k
PACKAGE = vq100
PCF = pins.pcf

all: $(PROJ).bin

# Synthesis (Verilog -> JSON)
$(PROJ).json: $(PROJ).v
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
