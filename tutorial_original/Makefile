# Makefile for Nandland Go Board (iCE40HX1K-VQ100)

PROJ = tutorial_led_blink
DEVICE = hx1k
PACKAGE = vq100
PCF = constraints.pcf

all: $(PROJ).bin

# Synthesis (Verilog -> JSON)
$(PROJ).json: $(PROJ).v
	@echo "Synthesizing..."
	@yosys -q -p "synth_ice40 -top $(PROJ) -json $@" $<

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
