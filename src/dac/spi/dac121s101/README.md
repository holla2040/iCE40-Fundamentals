# DAC

SPI master for DAC121S101 12-bit DAC. Outputs a 200-point ramp (0-4095) on trigger.

## Pins

| Signal | Pin | Description |
|--------|-----|-------------|
| trigger_in | 55 | Rising edge starts sweep |
| dac_cs_n | PMOD | SPI chip select (active low) |
| dac_sclk | PMOD | SPI clock (6 MHz) |
| dac_mosi | PMOD | SPI data to DAC |
| busy | PMOD | High during sweep |
| done | PMOD | Pulses high when complete |

## Usage

```
make
make flash
```
