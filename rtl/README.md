# RTL

GPU core, AXI integration, and DDR3/BRAM support logic, in SystemVerilog
(`.sv`) and Verilog (`.v`).

- `warp_gpu_v1_0.v` — top-level packaged Vivado IP wrapper (AXI4-Lite
  peripheral entry point).
- `warp_gpu_axi.sv` — AXI4-Lite slave register interface
  (`warp_gpu_v1_0_S00_AXI`) plus a Gray-code CDC counter (`gray_cdc`).
- `warp_gpu_soc.sv` — top-level GPU memory/SoC integration
  (`gpuMemoryTop`), instantiates the cluster, memory controller, and
  load/store units.
- `fullGPUSystem.sv` — board-level top (MicroBlaze block design, HDMI/DDR3
  wiring, clock domain crossing via `cdcFifo`).
- `cluster.sv` — SIMT core cluster / instruction dispatch
  (`gpuClusterSystem`).
- `warp_scheduler.sv` — per-core scheduling cluster (`gpuCoreCluster`):
  round-robin with one-cycle lookahead, greedy-then-oldest issue.
- `lane.sv` — single SIMT lane/context datapath (multiply and divide
  are separate execution units from the ALU; divide is unsigned only).
- `regFile.sv` — dual-read/single-write register file
  (`twoReadOneWriteRegFile`), 256 entries deep, instantiated as simple
  dual-port BRAM.
- `load_store.sv` — shared/global memory load-store unit; coalesces
  adjacent lanes' accesses into a single 128-bit transaction/cycle.
- `divide.sv` — shared, unsigned-only divide unit pool.
- `memMux.sv`, `memController.sv`, `ram_reader.sv` — shared/DDR3 memory
  arbitration (GPU vs. VGA scanout), byte-enabled shared memory, and
  BRAM-backed instruction/data loading.
- `axi_wrapper.sv`, `cdcFifo.sv` — AXI4-Lite bridge and clock-domain-
  crossing FIFO between the GPU's core clock and the memory/AXI clocks.
- `videoController.sv` — HDMI scanout controller; instantiates the VGA
  timing generator and RealDigital HDMI TX IP from
  [`../third_party`](../third_party).
- `testbench.sv` — cluster-level testbench.
- `coe/core_00.coe` … `core_19.coe` — per-core BRAM initialization
  vectors (`memory_initialization_radix=16`), one per lane/context.

See [`../firmware`](../firmware) for the host driver that talks to this
core over its AXI command FIFO, [`../fpga_assembler`](../fpga_assembler)
for the assembler that generates the instruction words it consumes, and
[`../third_party`](../third_party) for the SD card and HDMI TX
dependencies.
