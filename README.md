# warp-simd-fpga-gpu

A SIMT GPU built from scratch on an FPGA: custom 32-bit ISA, a
tile-based triangle rasterizer, a Rust assembler, and a MicroBlaze
host driver running a heavily pipelined, fixed-point software 3D pipeline, targeting a Xilinx
Spartan-7 (`xc7s50csga324-1IL`). It renders live to a real monitor
over HDMI at 640x480, 30 FPS.

<p align="center">
  <img src="media/demo.gif" alt="Spinning shaded octahedron rendered live on the GPU, output over HDMI" width="640">
</p>

<p align="center">
  <a href="media/demo.mp4">Full-resolution video</a>
</p>

## Architecture

```mermaid
flowchart LR
    subgraph Host["MicroBlaze (soft CPU)"]
        FW["firmware/main.c\nfixed-point Q16.16 3D pipeline\n(matrix xform, clip, persp. divide)"]
    end
    subgraph GPU["warp_gpu core (RTL), runtime-programmable clock, 80 MHz achieved"]
        AXI["warp_gpu_axi.sv\nAXI4-Lite command FIFO + status regs"]
        IBUF["shared instruction buffer\nhead/tail, CPU-written, 1024 entries"]
        SCHED["warp_scheduler.sv\ngreedy-then-oldest round robin\n20 lanes x up to 16 contexts"]
        LANE["lane.sv x20\nALU / shift / compare per lane"]
        MULDIV["separate multiply + divide units\n(divide is unsigned only)"]
        LSU["load_store.sv\ncoalesces adjacent lanes into\n1x 128-bit txn/cycle, 4 loads + 4 stores/cycle"]
        CDC["cdcFifo.sv / gray_cdc\nclock-domain crossing"]
    end
    subgraph MC["memController.sv"]
        SRAM["shared SRAM, 32KB\n(software-managed, no cache)"]
        MUX["GPU / VGA arbiter\nswitches when SRAM fb buffer < half full"]
    end
    VGA["VGA/HDMI scanout"]
    DDR3["DDR3 (1 Gb)\ndual framebuffers @ 0x0 / 0x96000\nram_reader.sv, up to 1.6 GB/s\nSD-card preloadable"]

    FW -- "instruction words" --> AXI --> IBUF --> SCHED
    SCHED --> LANE & MULDIV --> LSU --> CDC --> MC
    MC --> SRAM --> MUX --> VGA
    MC <--> DDR3
```

- **20 SIMT lanes × up to 16 hardware contexts (warps)**: 20 lanes was
  chosen because it cleanly lets the rasterizer fill the screen's x-axis
  in two iterations. Each lane/context pair has 16 addressable
  registers; `r15` is hardwired to that lane's thread ID rather than
  being general-purpose.
- **Integer math**: Because this was designed for a maximum-throughput GPU on a small FPGA board, there wasn't room in the design for
  floating-point units. Therefore, the host firmware does all vertex/matrix
  math in Q16.16 fixed point before handing triangles to the GPU.
  Because operands are fixed-point, many operations, particularly
  multiply and divide, require compressing operands down to 16-bit
  fixed point before the hardware execution units can operate on them.
- **Predication instead of branching**: `skip_*` compare instructions
  disable a lane for the next N dynamic instructions based on a
  register compare, rather than taking a branch.
- **Scheduler**: round-robin across contexts with one-cycle lookahead.
  It checks whether the next context can actually issue next cycle,
  and if not, skips ahead two contexts rather than stalling on it.
  Issue policy is greedy-then-oldest: a context keeps issuing ALU
  instructions back-to-back for as long as it can before yielding.
  This spreads contexts out to different points in the shared
  instruction buffer, which in practice keeps a variety of operand and
  instruction types available to the scheduler on any given cycle,
  keeping the ALU, multiply/divide, and load/store pipelines full.
- **Shared instruction buffer**: a single CPU-writable buffer (1024
  entries in this build) with a head and tail, read by 16 independent
  per-context program counters. The tail advances when MicroBlaze
  writes new instructions; the head advances only once every context's
  PC has moved past that slot.
- **Context count is runtime-configurable**, 1 to 16, via `barrier`
  instructions. `barrier` does double duty as both a full GPU
  memory/execution sync point and the mechanism for reprogramming how
  many contexts are active.
- **Memory coalescing and pipelining**: adjacent lanes' loads/stores
  are grouped into a single 128-bit transaction, one per cycle, rather
  than one transaction per lane. The load/store units can each sustain
  4 loads/stores per cycle, with 2 loads or store issues in flight inside the
  GPU lanes itself, and up to 80 DDR3 128-bit loads and 80 DDR3 128-bit
  stores in flight simultaneously further down the pipeline (memory
  controller, CDC, MIG).
- **Two memory spaces**: shared SRAM (`lw`/`sw`, 32KB in this build)
  and DDR3-backed global memory (`lwg`/`swg`), bridged through a
  clock-domain-crossing FIFO (`cdcFifo.sv`) between the GPU core clock
  and the memory-controller clock. The GPU core's clock is
  runtime-programmable via the CDC boundary, reconfigured live over
  the `clk_wiz` DRP interface (see `reconfig_clk()` in
  `firmware/main.c`); 80 MHz achieved on hardware.
- **No cache**: shared SRAM is used as a software-managed cache
  instead, and DDR3 latency (tens of cycles) is low enough relative to
  a discrete GPU's memory hierarchy that a hardware cache wasn't worth
  the area.
- **Display**: the memory controller multiplexes DDR3 access between
  the GPU and the VGA/HDMI controller, switching dynamically based on
  the fill level of an SRAM framebuffer buffer (up to 2048 pixels); it
  switches over once that buffer drops below half full. A dual
  framebuffer in DDR3 (base addresses `0x0` and `0x96000`) eliminates
  tearing. DDR3 capacity is 1 Gb; `ram_reader.sv` sustains up to
  1.6 GB/s of traffic, MIG-permitting. DDR3 contents can also be
  pre-initialized from a microSDHC card (see
  [`third_party/sdcard`](third_party/sdcard)); in theory this could be
  used to offload textures for sprite copying, or to support a
  texture-mapped triangle kernel instead of the current flat/Gouraud
  shading.
- **Host-driven rendering**: the MicroBlaze firmware does vertex
  transform, clipping, and perspective divide in Q16.16 fixed point,
  then hand-assembles a tile rasterizer program directly into GPU
  instruction words per triangle. There's no fixed-function triangle
  setup in hardware.

### Compile-time parameters

Lane count, instruction buffer depth, and shared memory size are all
configurable at compile time:

| Parameter | This build | Constraint |
|---|---|---|
| Lane count | 20 | must be a multiple of 4, above the design's minimum |
| Instruction buffer depth | 1024 entries | must be a power of 2 |
| Shared memory size | 32KB | must be a power of 2 |

These three were tuned together for the best performance/utilization
tradeoff on the `xc7s50csga324-1IL`; the design could in theory be
retargeted to a different board with different values.

### AXI4-Lite status registers

| Register | Meaning |
|---|---|
| 0 | Instruction buffer (ibuf) fill level |
| 1 | Number of pending CPU writes not yet retired into shared memory |
| 2 | Currently-displayed framebuffer index, packed with the current `drawX`/`drawY` scan position |

## ISA

32-bit fixed-width instructions, opcode always in bits `[31:28]`,
register file `r0`..`r15`. Full authoritative reference (with exact
bit layouts) lives in the assembler's
[header comment](fpga_assembler/src/main.rs); summary:

| Class | Mnemonics | Opcode | Notes |
|---|---|---|---|
| ALU | `add`, `sub` | `0000` | bit18 selects add/sub; bit19 = immediate flag |
| ALU | `and`, `or` | `0001` | bit18 selects and/or |
| ALU | `xor` | `0010` | |
| Multiply | `mul` | `0011` | separate execution unit from the ALU |
| Divide | `div` | `0100` | separate execution unit from the ALU; unsigned only |
| Shift | `lsl`, `lsr`, `asr` | `0101` | shift amount ∈ {1,2,4,8,16,24} |
| Compare (imm) | `skip_lt/le/eq/ne/gt/ge` | `0110` | `CMPi`: disables the lane for N dynamic instructions |
| Compare (reg) | `skip_lt/le/eq/ne/gt/ge` | `0111` | `CMP`, register operand |
| Load | `lw` | `1000` | shared/SRAM: `rD <- M[rS1 + (rS2\|imm19)]` |
| Load | `lwg` | `1001` | global/DDR3 |
| Store | `sw` | `1010` | shared/SRAM, immediate offset, optional byte-enable |
| Store | `swg` | `1011` | global/DDR3 |
| Compare/set | `slt`, `slte` | `1100` | writes 1/0 to `rD` |
| CPU store | `cpu_store` | `1101` | host CPU injects a data block directly into shared memory |
| Barrier | `barrier` | `1111` | memory sync + context-count reprogramming |
| Data | `.data`, `.word` | n/a | raw word emit, assembler directive |

## Layout

- [`fpga_assembler/`](fpga_assembler): Rust assembler for the ISA
  above. Test programs in `fpga_assembler/src/*.s` implement the tile
  rasterizer, framebuffer clear, and sRGB LUT setup.
- [`firmware/`](firmware): MicroBlaze host driver: clock
  reconfiguration, LUT/framebuffer uploads, and the fixed-point 3D
  pipeline that emits GPU instructions per triangle.
- [`rtl/`](rtl): GPU core RTL: SIMT cluster/scheduler, lanes, register
  files, load/store and divide units, AXI4-Lite integration, memory
  arbitration, and board-level top. See [`rtl/README.md`](rtl/README.md)
  for the full file-by-file breakdown.
- [`hw/`](hw): Vivado hardware handoff (`.xsa`) and pin/timing
  constraints (`.xdc`) for the target board.
- [`third_party/`](third_party): SD card and HDMI TX dependencies
  carried over from the previous iteration of this project; see that
  folder's README for attribution.
- [`media/`](media): demo capture.

## Setup and usage

### Prerequisites

- Xilinx Vivado 2022.2 (for synthesis and implementation)
- Xilinx Vitis (for firmware build/programming)
- Spartan-7 target board (`xc7s50csga324-1IL`)
- microSDHC card, for preloading DDR3 contents

### Steps

1. **Vivado setup**
   - Create a MicroBlaze block design and attach the `warp_gpu_1_0` IP
     over AXI4-Lite (see [`rtl/warp_gpu_v1_0.v`](rtl/warp_gpu_v1_0.v)),
     or import [`hw/fullSystemTop.xsa`](hw/fullSystemTop.xsa) directly.
   - Apply [`hw/fullSystemTop.xdc`](hw/fullSystemTop.xdc) for pin/timing
     constraints.
   - Instantiate all block RAMs as **simple dual-port** memory:
     - Register files ([`rtl/regFile.sv`](rtl/regFile.sv)): 256 entries
       deep.
     - Shared memory: enable the byte-enable feature.
2. **Testing**: simulate the scheduler/cluster, load/store and divide
   units, memory controller, and register file individually before
   testing end-to-end; [`rtl/testbench.sv`](rtl/testbench.sv) covers
   the cluster level.
3. **Programming**: generate (or reuse) the `.xsa`, build the Vitis
   platform and [`firmware/`](firmware) application against it, and
   preload DDR3 contents via the microSDHC card path
   ([`third_party/sdcard`](third_party/sdcard)).

## Status

Software rasterizer pipeline, assembler, and GPU core RTL are working
end-to-end over a command FIFO on hardware. The demo above is a live
capture, not a simulation.

## Contact

Questions or feedback are welcome. Reach out at
[alexanderg.123@outlook.com](mailto:alexanderg.123@outlook.com).
