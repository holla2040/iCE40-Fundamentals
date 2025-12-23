# ADC

SPI master for AD7476A 12-bit ADC. Triggers on pin 54 rising edge, reads 200 samples into block RAM.

## Pins

| Signal | Pin | Description |
|--------|-----|-------------|
| trigger_in | 54 | Rising edge starts acquisition |
| adc_cs_n | PMOD | SPI chip select (active low) |
| adc_sclk | PMOD | SPI clock (6 MHz) |
| adc_miso | PMOD | SPI data from ADC |
| busy | PMOD | High during acquisition |
| done | PMOD | Pulses high when complete |

## Usage

```
make
make flash
```
