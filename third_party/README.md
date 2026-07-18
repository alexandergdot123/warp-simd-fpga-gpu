# Third-party files

Carried over from the previous iteration of this project
([FPGA_GPU](https://github.com/alexandergdot123/FPGA_GPU)), unmodified
except where noted.

## `sdcard/`

- `sdcard_init.sv`: Zuofu Cheng (2024), for ECE 385. State machine
  wrapper that loads raw microSDHC blocks into memory ahead of the
  VHDL SD card driver below. Used to preload DDR3 contents from a
  microSDHC card.
- `SDCard.vhd`: XESS SDCard driver, wrapped by `sdcard_init.sv`.
- `vga.sv`: VGA timing generator (`drawX`/`drawY`, hsync/vsync),
  instantiated by [`../rtl/videoController.sv`](../rtl/videoController.sv).

## `hdmi_tx/`

RealDigital's HDMI TX IP (`encode.v`, `hdmi_tx_v1_0.v`,
`serdes_10_to_1.v`, `srldelay.v`), used for the physical HDMI output
signaling. Vendor-unmodified.
