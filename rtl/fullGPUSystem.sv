module fullSystemTop #(
    parameter int NUM_CORES = 32,
    parameter int sharedMemSize = 65536
)(
    input  logic Clk,
    input  logic reset_rtl_0,

    input  logic uart_rtl_0_rxd,
    output logic uart_rtl_0_txd,

    output logic        hdmi_tmds_clk_n,
    output logic        hdmi_tmds_clk_p,
    output logic [2:0]  hdmi_tmds_data_n,
    output logic [2:0]  hdmi_tmds_data_p,

//    input  logic sys_clk_n,
//    input  logic sys_clk_p,

    output logic [12:0] ddr3_addr,
    output logic [2:0]  ddr3_ba,
    output logic        ddr3_cas_n,
    output logic        ddr3_ck_n,
    output logic        ddr3_ck_p,
    output logic        ddr3_cke,
    output logic [1:0]  ddr3_dm,
    inout  wire [15:0] ddr3_dq,
    inout  wire [1:0]  ddr3_dqs_n,
    inout  wire [1:0]  ddr3_dqs_p,
    output logic        ddr3_odt,
    output logic        ddr3_ras_n,
    output logic        ddr3_reset_n,
    output logic        ddr3_we_n,

    output logic        ram_init_error,
    output logic        ram_init_done,

    output logic sd_sclk,
    output logic sd_mosi,
    output logic sd_cs,
    input  logic sd_miso,
    output logic [15:0] led
);
//    logic Clk;
//    assign Clk = clk_100;
    // ---------------------------
    // Cache <-> memoryController
    // ---------------------------
    logic [127:0] cacheDataWrite, cacheDataRead;
    logic [26:0]  cacheAddress;
    logic         cacheEnableGlobal, cacheEnableGlobalWrite;
    logic [15:0]  cacheWriteBytes;
    logic         cacheFinishedRead, cacheFinishedCommand;

    logic [127:0] ddr3DataWrite, ddr3DataRead;
    logic [26:0]  ddr3Address;
    logic         ddr3EnableGlobal, ddr3EnableGlobalWrite;
    logic [15:0]  ddr3WriteBytes;
    logic         ddr3FinishedRead, ddr3FinishedCommand;

    logic clk_slow;
    logic [26:0] clk_counter;
    logic [15:0] x, y;
    always_ff @(posedge clk_slow) begin
        if(reset_rtl_0)
            clk_counter <= '0;
        else
            clk_counter <= clk_counter + 1;
    
    end
    // ---------------------------
    // DDR "Alex" interface
    // ---------------------------
    logic [26:0]  alexAddress;
    logic [127:0] alexWriteData, alexReadData;
    logic [1:0]   alexMemEnable;
    logic [15:0]  alexWriteBytes;
    logic         alexFinishedMemAction, alexCommandAcknowledged, alexNewCommand;
    logic         processingAlexCommand;

    // ---------------------------
    // HDMI pipeline signals
    // ---------------------------
    logic [9:0] drawX, drawY;
    logic [7:0] red, green, blue;
    logic frame;
    logic [31:0] draw_concatenated;
    assign draw_concatenated = {11'h000, frame, drawY, drawX};

    // ---------------------------
    // MIG interface signals
    // ---------------------------
    localparam int ADDR_WIDTH     = 27;
    localparam int APP_DATA_WIDTH = 64;
    localparam int APP_MASK_WIDTH = 8;

    logic [ADDR_WIDTH-1:0]     app_addr, app_wr_addr, app_rd_addr;
    logic [2:0]                app_cmd,  app_wr_cmd,  app_rd_cmd;
    logic                      app_en,   app_wr_en,   app_rd_en;

    logic                      app_rdy;
    logic [APP_DATA_WIDTH-1:0] app_rd_data;
    logic                      app_rd_data_end;
    logic                      app_rd_data_valid;

    logic [APP_DATA_WIDTH-1:0] app_wdf_data, sd_ram_wdf_data, ram_reader_write_data;
    logic                      app_wdf_end,  sd_ram_wdf_end,  ram_reader_wdf_end;
    logic                      app_wdf_wren, sd_ram_wdf_wren, ram_reader_wdf_wren;
    logic [APP_MASK_WIDTH-1:0] app_wdf_mask, ram_reader_wdf_mask;
    logic                      app_wdf_rdy;

    logic ui_clk, ui_sync_rst;
    logic init_calib_complete;

    // ---------------------------
    // MIG clock: derive clk_ref_i from sys_clk_p/n
//    // ---------------------------
//    wire clk_ref_i;
//    IBUFDS #(
//        .DIFF_TERM("TRUE"),
//        .IBUF_LOW_PWR("FALSE")
//    ) u_ibufds_sysclk (
//        .I (sys_clk_p),
//        .IB(sys_clk_n),
//        .O (clk_ref_i)
//    );
//    logic clk_slow_locked;
    
//    clk_slow_creator clk_slow_creator_inst (
//        .reset(reset_rtl_0),
//        .clk_in1(Clk),
//        .clk_out1(clk_slow),
//        .locked(clk_slow_locked)
//    );   
    
    wire sys_rst = reset_rtl_0; // active-high
    assign ram_init_error = clk_counter[26];
    // ---------------------------
    // MicroBlaze block: 100 MHz
    // IMPORTANT: match the port names from your generated wrapper
    // (below uses the VERIFIED mb_usb_hdmi_top style names)
    logic [15:0] led2;
    // ---------------------------
    logic clk_lck;
    mb_block_2 mb_block_i (
        .clk_100MHz          (Clk),
        .reset_rtl_0         (~reset_rtl_0),   // BD expects active-low reset

        
//        .cache_finished_command(cacheFinishedCommand),
        .warp_gpu_cache_data_read      (cacheDataRead),
        .warp_gpu_cache_address       (cacheAddress),
        .warp_gpu_cache_data_write     (cacheDataWrite),
        .warp_gpu_cache_enable_global     (cacheEnableGlobal),
        .warp_gpu_cache_enable_global_write(cacheEnableGlobalWrite),
        .warp_gpu_cache_write_bytes    (cacheWriteBytes), //        .cache_finished_read(cache_finished_read),
        .warp_gpu_cache_finished_read(cacheFinishedRead),
        .mem_controller_ready_for_instruction(memControllerReady),
        .clk_slow(clk_slow),
        .warp_gpu_draw_concatenated   (draw_concatenated),
        .uart_rtl_0_rxd      (uart_rtl_0_rxd),
        .uart_rtl_0_txd      (uart_rtl_0_txd),
        .led(),
        .clk_lck(clk_lck)
    );

    // ---------------------------
    // MIG
    // ---------------------------
    mig_7series_0 u_mig_7series_0 (
        .ddr3_addr           (ddr3_addr),
        .ddr3_ba             (ddr3_ba),
        .ddr3_cas_n          (ddr3_cas_n),
        .ddr3_ck_n           (ddr3_ck_n),
        .ddr3_ck_p           (ddr3_ck_p),
        .ddr3_cke            (ddr3_cke),
        .ddr3_ras_n          (ddr3_ras_n),
        .ddr3_we_n           (ddr3_we_n),
        .ddr3_dq             (ddr3_dq),
        .ddr3_dqs_n          (ddr3_dqs_n),
        .ddr3_dqs_p          (ddr3_dqs_p),
        .ddr3_reset_n        (ddr3_reset_n),
        .ddr3_dm             (ddr3_dm),
        .ddr3_odt            (ddr3_odt),

        .init_calib_complete (init_calib_complete),

        .app_addr            (app_addr),
        .app_cmd             (app_cmd),
        .app_en              (app_en),
        .app_wdf_data        (app_wdf_data),
        .app_wdf_end         (app_wdf_end),
        .app_wdf_wren        (app_wdf_wren),
        .app_wdf_mask        (app_wdf_mask),

        .app_rd_data         (app_rd_data),
        .app_rd_data_end     (app_rd_data_end),
        .app_rd_data_valid   (app_rd_data_valid),
        .app_rdy             (app_rdy),
        .app_wdf_rdy         (app_wdf_rdy),

        .ui_clk              (ui_clk),
        .ui_clk_sync_rst     (ui_sync_rst),

        .sys_clk_i           (Clk),
        .clk_ref_i           (Clk),
        .device_temp         (),
        .sys_rst             (sys_rst),

        .app_sr_req          (1'b0),
        .app_ref_req         (1'b0),
        .app_zq_req          (1'b0),
        .app_sr_active       (),
        .app_ref_ack         (),
        .app_zq_ack          ()
    );

    // ---------------------------
    // SD init (runs on ui_clk)
    // ---------------------------
    sdcard_init #(
        .MAX_RAM_ADDRESS(27'h7FFFFF),
        .SDHC(1'b1)
    ) sdcard_init_0 (
        .clk            (ui_clk),
        .reset          (~init_calib_complete),

        .ram_cmd        (app_wr_cmd),
        .ram_en         (app_wr_en),
        .ram_rdy        (app_rdy),
        .ram_address    (app_wr_addr),

        .ram_wdf_data   (sd_ram_wdf_data),
        .ram_wdf_wren   (sd_ram_wdf_wren),
        .ram_wdf_rdy    (app_wdf_rdy),
        .ram_wdf_end    (sd_ram_wdf_end),

        .ram_init_error (),
        .ram_init_done  (ram_init_done),

        .cs_bo          (sd_cs),
        .sclk_o         (sd_sclk),
        .mosi_o         (sd_mosi),
        .miso_i         (sd_miso)
    );
    logic onCore;

    // ---------------------------
    // ram_reader (runs on ui_clk)
    // ---------------------------
    ram_reader ram_reader_inst (
        .clk              (ui_clk),
        .reset            (reset_rtl_0 || ~ram_init_done),

        .ram_address       (app_rd_addr),
        .ram_cmd           (app_rd_cmd),
        .ram_en            (app_rd_en),
        .ram_rdy           (app_rdy),

        .ram_rd_valid      (app_rd_data_valid),
        .ram_rd_data_end   (app_rd_data_end),
        .ram_rd_data       (app_rd_data),

        .ram_wdf_data      (ram_reader_write_data),
        .ram_wdf_wren      (ram_reader_wdf_wren),
        .ram_wdf_end       (ram_reader_wdf_end),
        .ram_wdf_mask      (ram_reader_wdf_mask),
        .ram_wdf_rdy       (app_wdf_rdy),

        .alexAddress           (alexAddress),
        .alexWriteData         (alexWriteData),
        .alexReadData          (alexReadData),
        .alexFinishedAction    (alexFinishedMemAction),
        .alexMemEnable         (alexMemEnable),
        .alexWriteBytes        (alexWriteBytes), // adapt if your ram_reader is 8-bit
//        .alexMemReady          (),
        .alexNewCommand        (alexNewCommand),
        .alexFinishedCommand   (alexCommandAcknowledged),
        .led(y)
    );

    // ---------------------------
    // MIG arbitration mux (COPY the verified behavior)
    // ---------------------------
    assign app_addr     = ram_init_done ? app_rd_addr : app_wr_addr;
    assign app_en       = ram_init_done ? app_rd_en   : app_wr_en;
    assign app_cmd      = ram_init_done ? app_rd_cmd  : app_wr_cmd;

    assign app_wdf_data = ram_init_done ? ram_reader_write_data : sd_ram_wdf_data;
    assign app_wdf_end  = ram_init_done ? ram_reader_wdf_end    : sd_ram_wdf_end;
    assign app_wdf_wren = ram_init_done ? ram_reader_wdf_wren   : sd_ram_wdf_wren;

    // Mask muxing: SD writes should be unmasked.
    // If your ram_reader_wdf_mask is already in MIG polarity, do NOT invert.
    assign app_wdf_mask = ram_init_done ? ram_reader_wdf_mask : 8'h00;

    // ---------------------------
    // memoryController (runs on ui_clk)
    // ---------------------------
    memoryController memoryController_inst (
        .clk(ui_clk),
        .reset(reset_rtl_0 || ~ram_init_done),

        .cacheDataWrite(ddr3DataWrite),
        .cacheAddress(ddr3Address),
        .cacheDataRead(ddr3DataRead),
        .cacheEnableGlobal(ddr3EnableGlobal),
        .cacheEnableGlobalWrite(ddr3EnableGlobalWrite),
        .cacheWriteBytes(ddr3WriteBytes),
        .cacheFinishedRead(ddr3FinishedRead),
        .cacheFinishedCommand(ddr3FinishedCommand),

        .drawX(drawX),
        .drawY(drawY),
        .red(red),
        .green(green),
        .blue(blue),
        .frame(frame),

        .alexAddress(alexAddress),
        .alexReadData(alexReadData),
        .alexWriteData(alexWriteData),
        .alexMemEnable(alexMemEnable),
        .alexWriteBytes(alexWriteBytes),
        .alexFinishedMemAction(alexFinishedMemAction),
        .alexCommandAcknowledged(alexCommandAcknowledged),
        .alexNewCommand(alexNewCommand)
        
//        .onCore(onCore)
    );

    // HDMI output stays on 100 MHz pixel pipeline input
    videoController videoControllerInst (
        .clk       (Clk),
        .reset     (reset_rtl_0),
        .red       (red),
        .green     (green),
        .blue      (blue),
//        .red       ('1),
//        .green     ('0),
//        .blue      ('0),
        .hdmi_clk_n(hdmi_tmds_clk_n),
        .hdmi_clk_p(hdmi_tmds_clk_p),
        .hdmi_tx_n (hdmi_tmds_data_n),
        .hdmi_tx_p (hdmi_tmds_data_p),
        .drawX     (drawX),
        .drawY     (drawY)
    );

    cdcFifo fifo_inst (
        .clk_slow(clk_slow),
        .clk_fast(ui_clk),
        .rst(reset_rtl_0 || ~ram_init_done),
        
        .cacheDataWrite(cacheDataWrite),
        .cacheAddress(cacheAddress),
        .cacheDataRead(cacheDataRead),
        .cacheEnableGlobal(cacheEnableGlobal),
        .cacheEnableGlobalWrite(cacheEnableGlobalWrite),
        .cacheWriteBytes(cacheWriteBytes),
        .cacheFinishedRead(cacheFinishedRead),
        .memControllerReady(memControllerReady),
        
        .ddr3DataWrite(ddr3DataWrite),
        .ddr3Address(ddr3Address),
        .ddr3DataRead(ddr3DataRead),
        .ddr3EnableGlobal(ddr3EnableGlobal),
        .ddr3EnableGlobalWrite(ddr3EnableGlobalWrite),
        .ddr3WriteBytes(ddr3WriteBytes),
        .ddr3FinishedRead(ddr3FinishedRead),
        .ddr3FinishedCommand(ddr3FinishedCommand),
        .clk_lck(clk_lck),
        .led(x)
    );
//    assign led[15:8] = x[7:0];
//    assign led[7:0] = y[7:0];
    assign led = y;
endmodule

