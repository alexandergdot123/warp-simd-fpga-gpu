# Hardware handoff

- `fullSystemTop.xsa`: Vivado hardware export (bitstream + block
  design metadata) for the full system, targeting the Spartan-7
  `xc7s50csga324-1IL`. Import this into Vitis to create the software
  platform that [`firmware/`](../firmware) builds against.
- `fullSystemTop.xdc`: physical/timing constraints (pin assignments,
  clocks) for the board.
