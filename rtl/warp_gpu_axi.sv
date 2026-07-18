`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////////
// warp_gpu AXI4-Lite -> gpuMemoryTop bridge
//
// Register map (word offsets, 32-bit each)
//   0x00: warp_gpu_reg0 = ibuf_fill            (RO)
//   0x04: warp_gpu_reg1 = cpu_write_fill       (RO)
//   0x08: warp_gpu_reg2 = draw_concatenated    (RO)
//   0x0C: warp_gpu_reg3 = reserved             (RO, currently 0)
//   0x10: warp_gpu_reg4 = instruction write    (WO/optionally readable back)
//
// Behavior
//   - Fully AXI4-Lite compliant for single-outstanding transaction
//   - Captures AW and W independently (no requirement they arrive same cycle)
//   - Optional backpressure: stalls writes to reg4 when fetch_queue_full=1
//   - Generates 1-cycle pulse warp_gpu_new_inst_valid when reg4 write completes
//
// Notes / concerns you should be aware of (not sugar-coated):
//   1) This is "single outstanding" AXI4-Lite. If your master violates AXI-Lite
//      and attempts multiple outstanding writes/reads, it will stall.
//   2) Writes to RO regs return SLVERR (BRESP=2'b10). Reads of undefined addrs
//      return SLVERR (RRESP=2'b10) with RDATA=0.
//   3) If software reads reg4 while writing it, you may see old/new depending
//      on cycle timing. That's normal unless you require stronger semantics.
//
//////////////////////////////////////////////////////////////////////////////////

module warp_gpu_v1_0_S00_AXI #(
    parameter int unsigned WARP_GPU_NUM_CORES       = 20,
    parameter int unsigned WARP_GPU_SHARED_MEM_SIZE = 16384,

    parameter int unsigned C_S_AXI_DATA_WIDTH = 32,
    parameter int unsigned C_S_AXI_ADDR_WIDTH = 16
)(
    // ----------------------------
    // AXI4-Lite Slave Interface
    // ----------------------------
    input  logic                          s_axi_aclk,
    input  logic                          s_axi_aresetn,

    input  logic [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  logic [2:0]                    s_axi_awprot,
    input  logic                          s_axi_awvalid,
    output logic                          s_axi_awready,

    input  logic [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input  logic [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  logic                          s_axi_wvalid,
    output logic                          s_axi_wready,

    output logic [1:0]                    s_axi_bresp,
    output logic                          s_axi_bvalid,
    input  logic                          s_axi_bready,

    input  logic [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  logic [2:0]                    s_axi_arprot,
    input  logic                          s_axi_arvalid,
    output logic                          s_axi_arready,

    output logic [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output logic [1:0]                    s_axi_rresp,
    output logic                          s_axi_rvalid,
    input  logic                          s_axi_rready,

    // ----------------------------
    // External DDR3/cache interface (propagate gpuMemoryTop)
    // ----------------------------
    output logic [127:0]                  warp_gpu_cache_data_write,
    output logic [26:0]                   warp_gpu_cache_address,
    input  logic [127:0]                  warp_gpu_cache_data_read,
    output logic                          warp_gpu_cache_enable_global,
    output logic                          warp_gpu_cache_enable_global_write,
    output logic [15:0]                   warp_gpu_cache_write_bytes,
    input  logic                          warp_gpu_cache_finished_read,
    input  logic                          mem_controller_ready_for_instruction,
    // Status input to expose to SW (RO)
    input  logic [31:0]                   warp_gpu_draw_concatenated,
    
    input logic clk_slow,
    input logic clk_slow_locked,
    output logic [15:0] led
);

    // ----------------------------
    // Localparams / address decode
    // ----------------------------
    localparam int unsigned WARP_GPU_NUM_REGS  = 5;

    // For 32-bit AXI data, ADDR_LSB=2 (byte addressing -> word index)
    localparam int unsigned WARP_GPU_ADDR_LSB  = (C_S_AXI_DATA_WIDTH/32) + 1;

    // Enough bits to index at least 0..4 (5 regs). 3 bits covers up to 0..7.
    localparam int unsigned WARP_GPU_ADDR_BITS = 3;

    // ----------------------------
    // Internal regs / signals
    // ----------------------------
    logic [WARP_GPU_NUM_REGS-1:0][C_S_AXI_DATA_WIDTH-1:0] warp_gpu_slv_regs;

    // From gpuMemoryTop
    logic [31:0] warp_gpu_ibuf_fill;
    logic [31:0] warp_gpu_cpu_write_fill;
    logic        warp_gpu_fetch_queue_full;

    // Instruction interface to gpuMemoryTop
    logic [31:0] warp_gpu_new_inst;
    logic        warp_gpu_new_inst_valid;

    // Write channel capture
    logic [C_S_AXI_ADDR_WIDTH-1:0]         warp_gpu_awaddr_q;
    logic                                  warp_gpu_aw_captured;

    logic [C_S_AXI_DATA_WIDTH-1:0]         warp_gpu_wdata_q;
    logic [(C_S_AXI_DATA_WIDTH/8)-1:0]     warp_gpu_wstrb_q;
    logic                                  warp_gpu_w_captured;

    logic [WARP_GPU_ADDR_BITS-1:0]         warp_gpu_wr_index;
    logic                                  warp_gpu_do_write;

    // Read channel capture
    logic [C_S_AXI_ADDR_WIDTH-1:0]         warp_gpu_araddr_q;
    logic [WARP_GPU_ADDR_BITS-1:0]         warp_gpu_rd_index;

    // ----------------------------
    // Convenience: index decode
    // ----------------------------
    assign warp_gpu_wr_index = warp_gpu_awaddr_q[WARP_GPU_ADDR_LSB + WARP_GPU_ADDR_BITS - 1 : WARP_GPU_ADDR_LSB];
    assign warp_gpu_rd_index = warp_gpu_araddr_q[WARP_GPU_ADDR_LSB + WARP_GPU_ADDR_BITS - 1 : WARP_GPU_ADDR_LSB];

    // Only reg4 is the instruction write register
    wire warp_gpu_target_is_inst_reg =
        (s_axi_awaddr[WARP_GPU_ADDR_LSB + WARP_GPU_ADDR_BITS - 1 : WARP_GPU_ADDR_LSB] == WARP_GPU_ADDR_BITS'(4));

    // Optional stall for instruction writes if fetch queue full
    wire warp_gpu_allow_aw_capture =
        (~warp_gpu_aw_captured) && (~s_axi_bvalid) && ((~warp_gpu_target_is_inst_reg) || (~warp_gpu_fetch_queue_full));

    wire warp_gpu_allow_w_capture  =
        (~warp_gpu_w_captured)  && (~s_axi_bvalid) && ((~warp_gpu_target_is_inst_reg) || (~warp_gpu_fetch_queue_full));

    // Complete write when both captured and no pending write response
    assign warp_gpu_do_write = warp_gpu_aw_captured && warp_gpu_w_captured && ~s_axi_bvalid;

    // ----------------------------
    // AXI WRITE ADDRESS/DATA capture (independent)
    // ----------------------------
    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_awready          <= 1'b0;
            s_axi_wready           <= 1'b0;
            warp_gpu_aw_captured   <= 1'b0;
            warp_gpu_w_captured    <= 1'b0;
            warp_gpu_awaddr_q      <= '0;
            warp_gpu_wdata_q       <= '0;
            warp_gpu_wstrb_q       <= '0;
        end else begin
            // pulse-ready behavior
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;

            if (s_axi_awvalid && warp_gpu_allow_aw_capture) begin
                s_axi_awready        <= 1'b1;
                warp_gpu_aw_captured <= 1'b1;
                warp_gpu_awaddr_q    <= s_axi_awaddr;
            end

            if (s_axi_wvalid && warp_gpu_allow_w_capture) begin
                s_axi_wready       <= 1'b1;
                warp_gpu_w_captured <= 1'b1;
                warp_gpu_wdata_q    <= s_axi_wdata;
                warp_gpu_wstrb_q    <= s_axi_wstrb;
            end

            if (warp_gpu_do_write) begin
                // clear after committing write
                warp_gpu_aw_captured <= 1'b0;
                warp_gpu_w_captured  <= 1'b0;
            end
        end
    end

    // ----------------------------
    // Register file update
    // ----------------------------
    logic [31:0] ibuf_fill_sync;
    logic [31:0] cpu_write_fill_sync;
    logic [31:0] warp_gpu_draw_concatenated_sync;
    gray_cdc #(.W(32)) u_ibuf_cdc (
        .src_clk(clk_slow), .src_bin(warp_gpu_ibuf_fill),
        .dst_clk(s_axi_aclk), .dst_bin(ibuf_fill_sync)
    );
    
    gray_cdc #(.W(32)) u_cpuwr_cdc (
        .src_clk(clk_slow), .src_bin(warp_gpu_cpu_write_fill),
        .dst_clk(s_axi_aclk), .dst_bin(cpu_write_fill_sync)
    );
    integer warp_gpu_bi;
    always_ff @(posedge s_axi_aclk) begin
        // continuously refresh RO regs
        warp_gpu_slv_regs[0] <= ibuf_fill_sync;
        warp_gpu_slv_regs[1] <= cpu_write_fill_sync;
        warp_gpu_slv_regs[2] <= warp_gpu_draw_concatenated_sync;
         // reserved for future status
        warp_gpu_draw_concatenated_sync <= warp_gpu_draw_concatenated;
        if(~s_axi_aresetn)
            warp_gpu_slv_regs[3] <= 32'hAAAA5555;
        else
            warp_gpu_slv_regs[3] <= ~warp_gpu_slv_regs[3];
        // commit write
        if (warp_gpu_do_write) begin
            unique case (warp_gpu_wr_index)
                WARP_GPU_ADDR_BITS'(4): begin
                    for (warp_gpu_bi = 0; warp_gpu_bi < (C_S_AXI_DATA_WIDTH/8); warp_gpu_bi++) begin
                        if (warp_gpu_wstrb_q[warp_gpu_bi]) begin
                            warp_gpu_slv_regs[4][warp_gpu_bi*8 +: 8] <= warp_gpu_wdata_q[warp_gpu_bi*8 +: 8];
                        end
                    end
                end
                default: begin
                    // ignore writes to RO regs; response channel will SLVERR
                end
            endcase
        end
    end

    // ----------------------------
    // AXI WRITE RESPONSE (B channel)
    // ----------------------------
    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= 2'b00; // OKAY
        end else begin
            if (warp_gpu_do_write) begin
                s_axi_bvalid <= 1'b1;
                // OKAY only for reg4 writes; SLVERR for others
                s_axi_bresp  <= (warp_gpu_wr_index == WARP_GPU_ADDR_BITS'(4)) ? 2'b00 : 2'b10;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // ----------------------------
    // AXI READ ADDRESS + READ RESPONSE (AR/R channel)
    // Single outstanding read
    // ----------------------------
    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_arready    <= 1'b0;
            s_axi_rvalid     <= 1'b0;
            s_axi_rresp      <= 2'b00;
            s_axi_rdata      <= '0;
            warp_gpu_araddr_q <= '0;
        end else begin
            s_axi_arready <= 1'b0;

            // accept read address when no outstanding read response
            if (s_axi_arvalid && ~s_axi_rvalid) begin
                s_axi_arready     <= 1'b1;
                warp_gpu_araddr_q <= s_axi_araddr;

                // respond immediately (registered outputs)
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00;

                unique case (s_axi_araddr[WARP_GPU_ADDR_LSB + WARP_GPU_ADDR_BITS - 1 : WARP_GPU_ADDR_LSB])
                    WARP_GPU_ADDR_BITS'(0): s_axi_rdata <= warp_gpu_slv_regs[0];
                    WARP_GPU_ADDR_BITS'(1): s_axi_rdata <= warp_gpu_slv_regs[1];
                    WARP_GPU_ADDR_BITS'(2): s_axi_rdata <= warp_gpu_slv_regs[2];
                    WARP_GPU_ADDR_BITS'(3): s_axi_rdata <= warp_gpu_slv_regs[3];
                    WARP_GPU_ADDR_BITS'(4): s_axi_rdata <= warp_gpu_slv_regs[4];
                    default: begin
                        s_axi_rdata <= '0;
                        s_axi_rresp <= 2'b10; // SLVERR
                    end
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

    // ----------------------------
    // Instruction pulse generation
    // ----------------------------
    assign warp_gpu_new_inst = warp_gpu_slv_regs[4];

    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            warp_gpu_new_inst_valid <= 1'b0;
        end else begin
            // 1-cycle pulse when a reg4 write commits
            warp_gpu_new_inst_valid <= (warp_gpu_do_write && (warp_gpu_wr_index == WARP_GPU_ADDR_BITS'(4)));
        end
    end

    logic [31:0] cdc_to_fifo;


    logic gpuNewInstruction, fifoRead, fifoEmpty;
    fifo_generator_0 instructionCDCFifo (
        .full(),
        .din(warp_gpu_new_inst), //172 + 8
        .wr_en(warp_gpu_new_inst_valid),
        
        .empty(fifoEmpty),
        .dout(cdc_to_fifo),
        .rd_en(fifoRead),
        
        .rst(~s_axi_aresetn),
        .wr_clk(s_axi_aclk),
        .rd_clk(clk_slow),
        
        .wr_rst_busy(),
        .rd_rst_busy()
    );

    assign fifoRead = ~fifoEmpty;
    logic ever_received_val;
    always_ff @(posedge clk_slow) begin
        if(~s_axi_aresetn) begin
            gpuNewInstruction <= '0;
            ever_received_val <= '0;    
        end
        else begin
            gpuNewInstruction <= fifoRead;
            if(gpuNewInstruction)
                ever_received_val <= '1;
        end
    
    end
//    assign led[15] = ever_received_val;
    // ----------------------------
    // gpuMemoryTop instance
    // ----------------------------
    gpuMemoryTop #(
        .NUM_CORES      (WARP_GPU_NUM_CORES),
        .sharedMemSize  (WARP_GPU_SHARED_MEM_SIZE)
    ) gpusoc (
        .clk                    (clk_slow),
        .rst                    ((~s_axi_aresetn) || (~clk_slow_locked)),

        .new_inst               (cdc_to_fifo),
        .new_inst_valid         (gpuNewInstruction),
        .fetch_queue_full       (warp_gpu_fetch_queue_full),

        .cacheDataWrite         (warp_gpu_cache_data_write),
        .cacheAddress           (warp_gpu_cache_address),
        .cacheDataRead          (warp_gpu_cache_data_read),
        .cacheEnableGlobal      (warp_gpu_cache_enable_global),
        .cacheEnableGlobalWrite (warp_gpu_cache_enable_global_write),
        .cacheWriteBytes        (warp_gpu_cache_write_bytes),
        .cacheFinishedRead      (warp_gpu_cache_finished_read),
        .memControllerReady(mem_controller_ready_for_instruction),
        .ibuf_fill              (warp_gpu_ibuf_fill),
        .cpu_write_fill         (warp_gpu_cpu_write_fill),
        .led(led)
    );

endmodule
module gray_cdc #(parameter int W = 10) (
    input  logic         src_clk,
    input  logic [W-1:0] src_bin,    // must change by <= 1 per src_clk
    input  logic         dst_clk,
    output logic [W-1:0] dst_bin
);
    logic [W-1:0] gray_q;
    always_ff @(posedge src_clk)
        gray_q <= src_bin ^ (src_bin >> 1);          // bin -> gray

    (* ASYNC_REG = "TRUE" *) logic [W-1:0] g_s1, g_s2;
    always_ff @(posedge dst_clk) begin
        g_s1 <= gray_q;
        g_s2 <= g_s1;
    end

    always_comb begin
        dst_bin[W-1] = g_s2[W-1];
        for (int b = W-2; b >= 0; b--)
            dst_bin[b] = dst_bin[b+1] ^ g_s2[b];     // gray -> bin
    end
endmodule