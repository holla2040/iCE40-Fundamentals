# Makefile for Serial UART project (iCE40HX1K-VQ100)
# Nandland Go Board - 115200 baud serial output

PROJ = serial_top
DEVICE = hx1k
PACKAGE = vq100
PCF = pins.pcf

SRCS = serial_top.v uart_tx.v

all: $(PROJ).bin

# Synthesis (Verilog -> JSON)
$(PROJ).json: $(SRCS)
	@echo "Synthesizing..."
	@yosys -q -p "read_verilog $(SRCS); synth_ice40 -top top -json $@"

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
