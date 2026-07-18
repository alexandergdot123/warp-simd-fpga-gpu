`timescale 1 ns / 1 ps

// AXI4-Lite -> gpuMemoryTop bridge
// - 4 dummy/status regs: slv_regs[0..3]
// - instruction write reg: slv_regs[4] (write-only from AXI side; readable back if you want)
// - Writing reg4 generates a 1-cycle pulse new_inst_valid (and drives new_inst)
// - Propagates gpuMemoryTop cache signals outward
module gpuMemoryTop_axi4lite_bridge #(
    parameter int NUM_CORES = 32,
    parameter int sharedMemSize = 65536,

    parameter int C_S_AXI_DATA_WIDTH = 32,
    parameter int C_S_AXI_ADDR_WIDTH = 16
)(
    // AXI4-Lite
    input  logic                          S_AXI_ACLK,
    input  logic                          S_AXI_ARESETN,

    input  logic [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  logic [2:0]                    S_AXI_AWPROT,
    input  logic                          S_AXI_AWVALID,
    output logic                          S_AXI_AWREADY,

    input  logic [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input  logic [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  logic                          S_AXI_WVALID,
    output logic                          S_AXI_WREADY,

    output logic [1:0]                    S_AXI_BRESP,
    output logic                          S_AXI_BVALID,
    input  logic                          S_AXI_BREADY,

    input  logic [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  logic [2:0]                    S_AXI_ARPROT,
    input  logic                          S_AXI_ARVALID,
    output logic                          S_AXI_ARREADY,

    output logic [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output logic [1:0]                    S_AXI_RRESP,
    output logic                          S_AXI_RVALID,
    input  logic                          S_AXI_RREADY,



    // === External DDR3/cache interface (propagate gpuMemoryTop) ===
    output logic [127:0]                  cacheDataWrite,
    output logic [26:0]                   cacheAddress,
    input  logic [127:0]                  cacheDataRead,
    output logic                          cacheEnableGlobal,
    output logic                          cacheEnableGlobalWrite,
    output logic [15:0]                   cacheWriteBytes,
    input  logic                          cacheFinishedRead,
    input  logic                          cacheFinishedCommand,
    
    input logic [31:0] draw_concatenated
);

    // ----------------------------
    // Register map (word offsets)
    // ----------------------------
    // 0x00: slv_regs[0] = dummy0_in (RO)
    // 0x04: slv_regs[1] = dummy1_in (RO)
    // 0x08: slv_regs[2] = dummy2_in (RO)
    // 0x0C: slv_regs[3] = dummy3_in (RO)

    localparam int NUM_REGS  = 5;
    localparam int ADDR_LSB  = (C_S_AXI_DATA_WIDTH/32) + 1; // 2 for 32-bit data bus
    localparam int ADDR_BITS = 3; // enough to index 0..7 (we use 0..4)
    logic [31:0] ibuf_fill, cpu_write_fill;
    logic [4:0][C_S_AXI_DATA_WIDTH-1:0] slv_regs ;

    // ----------------------------
    // AXI write channel (improved)
    // - accepts AW and W independently
    // - completes write when both captured
    // - single outstanding write response (AXI4-Lite compliant)
    // ----------------------------
    logic [C_S_AXI_ADDR_WIDTH-1:0] awaddr_q;
    logic                          aw_captured;

    logic [C_S_AXI_DATA_WIDTH-1:0] wdata_q;
    logic [(C_S_AXI_DATA_WIDTH/8)-1:0] wstrb_q;
    logic                          w_captured;

    logic [ADDR_BITS-1:0]          wr_index;
    logic                          do_write;
    logic [1:0]                    bresp_next;

    // Optional: stall writes to reg4 when gpuMemoryTop says fetch_queue_full
    logic fetch_queue_full;

    assign wr_index = awaddr_q[ADDR_LSB + ADDR_BITS - 1 : ADDR_LSB];

    // Ready when we can capture, and we don't already have something pending
    // If you're writing reg4 and the fetch queue is full, we stall acceptance.
    wire target_is_inst_reg = (S_AXI_AWADDR[ADDR_LSB + ADDR_BITS - 1 : ADDR_LSB] == 3'd4);
    wire allow_aw_capture   = ~aw_captured & ~S_AXI_BVALID & (~target_is_inst_reg | ~fetch_queue_full);
    wire allow_w_capture    = ~w_captured  & ~S_AXI_BVALID & (~target_is_inst_reg | ~fetch_queue_full);

    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;
            aw_captured   <= 1'b0;
            w_captured    <= 1'b0;
            awaddr_q      <= '0;
            wdata_q       <= '0;
            wstrb_q       <= '0;
        end else begin
            // default deassert; we pulse ready high when capturing
            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;

            if (S_AXI_AWVALID && allow_aw_capture) begin
                S_AXI_AWREADY <= 1'b1;
                aw_captured   <= 1'b1;
                awaddr_q      <= S_AXI_AWADDR;
            end

            if (S_AXI_WVALID && allow_w_capture) begin
                S_AXI_WREADY <= 1'b1;
                w_captured   <= 1'b1;
                wdata_q      <= S_AXI_WDATA;
                wstrb_q      <= S_AXI_WSTRB;
            end

            // once write completes, clear captured flags (below in do_write block)
            if (do_write) begin
                aw_captured <= 1'b0;
                w_captured  <= 1'b0;
            end
        end
    end

    assign do_write = aw_captured & w_captured & ~S_AXI_BVALID; // complete write when both are present

    // Write into regs (only reg4 is writable by AXI; other regs are "dummy slots" driven from inputs)
    integer bi;
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            // Keep regs reset-clean. (No insane loop to 2**ADDR_WIDTH.)
            for (int i = 0; i < NUM_REGS; i++) begin
                slv_regs[i] <= '0;
            end
        end else begin
            // continuously refresh dummy regs from inputs
            slv_regs[0] <= ibuf_fill;
            slv_regs[1] <= cpu_write_fill;
            slv_regs[2] <= draw_concatenated;
//            slv_regs[3] <= dummy3_in;

            if (do_write) begin
                unique case (wr_index)
                    3'd4: begin
                        for (bi = 0; bi < (C_S_AXI_DATA_WIDTH/8); bi++) begin
                            if (wstrb_q[bi]) begin
                                slv_regs[4][bi*8 +: 8] <= wdata_q[bi*8 +: 8];
                            end
                        end
                    end
                    default: begin
                        // ignore writes to RO dummy regs (or you could SLVERR)
                    end
                endcase
            end
        end
    end

    // Write response
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_BVALID <= 1'b0;
            S_AXI_BRESP  <= 2'b00; // OKAY
        end else begin
            if (do_write) begin
                // If someone tries to write RO regs, you can choose OKAY or SLVERR.
                // Here: OKAY for reg4, SLVERR for others.
                S_AXI_BVALID <= 1'b1;
                S_AXI_BRESP  <= (wr_index == 3'd4) ? 2'b00 : 2'b10; // 2'b10 = SLVERR
            end else if (S_AXI_BVALID && S_AXI_BREADY) begin
                S_AXI_BVALID <= 1'b0;
            end
        end
    end

    // ----------------------------
    // AXI read channel
    // - single outstanding read response
    // - rdata registered
    // ----------------------------
    logic [C_S_AXI_ADDR_WIDTH-1:0] araddr_q;
    logic [ADDR_BITS-1:0]          rd_index;

    assign rd_index = araddr_q[ADDR_LSB + ADDR_BITS - 1 : ADDR_LSB];

    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_ARREADY <= 1'b0;
            S_AXI_RVALID  <= 1'b0;
            S_AXI_RRESP   <= 2'b00;
            S_AXI_RDATA   <= '0;
            araddr_q      <= '0;
        end else begin
            S_AXI_ARREADY <= 1'b0;

            // accept address when no outstanding read
            if (S_AXI_ARVALID && ~S_AXI_RVALID) begin
                S_AXI_ARREADY <= 1'b1;
                araddr_q      <= S_AXI_ARADDR;

                // produce read response next cycle by setting RVALID now and RDATA now (registered)
                S_AXI_RVALID  <= 1'b1;
                S_AXI_RRESP   <= 2'b00;

                unique case (S_AXI_ARADDR[ADDR_LSB + ADDR_BITS - 1 : ADDR_LSB])
                    3'd0: S_AXI_RDATA <= slv_regs[0];
                    3'd1: S_AXI_RDATA <= slv_regs[1];
                    3'd2: S_AXI_RDATA <= slv_regs[2];
                    3'd3: S_AXI_RDATA <= slv_regs[3];
                    3'd4: S_AXI_RDATA <= slv_regs[4];
                    default: begin
                        S_AXI_RDATA <= '0;
                        S_AXI_RRESP <= 2'b10; // SLVERR
                    end
                endcase
            end else if (S_AXI_RVALID && S_AXI_RREADY) begin
                S_AXI_RVALID <= 1'b0;
            end
        end
    end

    // ----------------------------
    // gpuMemoryTop hookup
    // ----------------------------
    logic [31:0] new_inst;
    logic        new_inst_valid;

    assign new_inst       = slv_regs[4];

    // 1-cycle pulse when an instruction write completes successfully
    // (i.e., write accepted and response generated as OKAY for reg4)
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            new_inst_valid <= 1'b0;
        end else begin
            new_inst_valid <= (do_write && (wr_index == 3'd4)); // pulse
        end
    end

    gpuMemoryTop #(
        .NUM_CORES(NUM_CORES),
        .sharedMemSize(sharedMemSize)
    ) u_gpuMemoryTop (
        .clk                  (S_AXI_ACLK),
        .rst                  (~S_AXI_ARESETN),

        .new_inst             (new_inst),
        .new_inst_valid       (new_inst_valid),
        .fetch_queue_full     (fetch_queue_full),

        .cacheDataWrite       (cacheDataWrite),
        .cacheAddress         (cacheAddress),
        .cacheDataRead        (cacheDataRead),
        .cacheEnableGlobal    (cacheEnableGlobal),
        .cacheEnableGlobalWrite(cacheEnableGlobalWrite),
        .cacheWriteBytes      (cacheWriteBytes),
        .cacheFinishedRead    (cacheFinishedRead),
        .cacheFinishedCommand (cacheFinishedCommand),
        
        .ibuf_fill(ibuf_fill),
        .cpu_write_fill(cpu_write_fill)
    );

endmodule
