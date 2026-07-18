# warp-simd-fpga-gpu

A SIMT/SIMD GPU built from scratch on an FPGA (Zynq), with a custom
32-bit fixed-width instruction set, a tile-based triangle rasterizer,
and a Rust assembler for the ISA.

## Layout

- [`fpga_assembler/`](fpga_assembler) — Rust assembler for the GPU's ISA.
  Register file `r0..r15`, ALU/shift/compare ops, shared (`lw`/`sw`) and
  global/DDR3 (`lwg`/`swg`) memory ops, predicated core-disable via
  `skip_*` compares, `barrier`, and `cpu_store` for host-uploaded data
  blocks. Test programs in `fpga_assembler/src/*.s` implement the
  rasterizer, framebuffer clear, and sRGB LUT setup.
- [`firmware/`](firmware) — Host driver (Zynq/MicroBlaze) that
  reconfigures the pixel clock, uploads LUTs/framebuffer clears, and
  drives the GPU with a small fixed-point (Q16.16) 3D pipeline —
  matrix transforms, perspective projection, clip-space vertex packing —
  to render shaded, depth-tested triangles.
- `rtl/` — GPU core RTL (coming soon).

## ISA overview

See the header comment in [`fpga_assembler/src/main.rs`](fpga_assembler/src/main.rs)
for the full instruction reference. Highlights:

- 16 lanes × 16 contexts (SIMT execution, per-lane predication)
- ALU: add/sub/and/or/xor/mul/div, shifts, set-less-than
- Compare-and-skip (`skip_lt`/`skip_eq`/...) turns lanes off for N
  dynamic instructions instead of branching
- Separate shared (SRAM) and global (DDR3) memory spaces
- `barrier` for memory sync + context-count reprogramming
- `cpu_store` for the host CPU to inject data blocks directly into
  shared memory (LUTs, vertex data, etc.)

## Status

Software rasterizer pipeline and assembler are working end-to-end
against the GPU core over a command FIFO; RTL sources to be added.
