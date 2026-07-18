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
- `warp_scheduler.sv` — per-core scheduling cluster (`gpuCoreCluster`);
  an earlier draft of the same module is kept commented out at the top
  of the file for reference.
- `lane.sv` — single SIMT lane/context datapath.
- `regFile.sv` — dual-read/single-write register file
  (`twoReadOneWriteRegFile`).
- `load_store.sv` — shared/global memory load-store unit.
- `divide.sv` — shared divide unit pool.
- `memMux.sv`, `memController.sv`, `ram_reader.sv` — shared/DDR3 memory
  arbitration and BRAM-backed instruction/data loading.
- `axi_wrapper.sv`, `cdcFifo.sv` — AXI4-Lite bridge and clock-domain-
  crossing FIFO between the GPU's core clock and the memory/AXI clocks.
- `testbench.sv` — cluster-level testbench.

See [`../firmware`](../firmware) for the host driver that talks to this
core over its AXI command FIFO, and [`../fpga_assembler`](../fpga_assembler)
for the assembler that generates the instruction words it consumes.
