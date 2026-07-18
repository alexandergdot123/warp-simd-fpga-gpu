module gpuMemoryTop #(parameter NUM_CORES = 16, parameter sharedMemSize = 65536)(
    input  logic        clk,
    input  logic        rst,

    // Frontend
    input  logic [31:0] new_inst,
    input  logic        new_inst_valid,
    output logic        fetch_queue_full,

    // === External DDR3 interface (to memory controller) ===
    output logic [127:0] cacheDataWrite,
    output logic [26:0]  cacheAddress,
    input  logic [127:0] cacheDataRead,
    output logic          cacheEnableGlobal,
    output logic          cacheEnableGlobalWrite,
    output logic [15:0]   cacheWriteBytes,
    input  logic          cacheFinishedRead,
    input logic           memControllerReady,
    
    output logic [31:0] ibuf_fill,
    output logic [31:0] cpu_write_fill,
    output logic [15:0] led
);

    // Internal connection wires
    logic [31:0]  loadAddress;
    logic         ddr3StartLoad;
    logic         sharedStartLoad;
    logic [31:0]  storeAddress;
    logic [127:0] storeValue;
    logic [15:0]  storeByteEnable;
    logic         sharedStartStore;
    logic         ddr3StartStore;

    logic [127:0] loadedDDR3Value;
    logic [127:0] loadedSharedValue;
    logic         loadDDR3Returned;
    logic         ddr3ReadyForLoad;
    logic         ddr3ReadyForStore;

    logic [NUM_CORES - 1 : 0] loadsEnabled, storesEnabled;
    
    logic [11:0] num_elems;
    logic [7:0] cpu_write_fill_level;
    assign cpu_write_fill = {24'h000000, cpu_write_fill_level};
    logic [15:0] cpu_side_address;
    always_ff @(posedge clk) begin
        if(rst) begin
            num_elems <= '0;
            cpu_side_address <= '0;
        end
        else begin
            if(num_elems == '0 && new_inst_valid && new_inst[31:28] == 4'b1101) begin
                num_elems <= new_inst[27:16];
                cpu_side_address <= new_inst[15:0];            
            end
            if(num_elems != '0 && new_inst_valid) begin
                num_elems <= num_elems - 1;
                cpu_side_address <= cpu_side_address + 1;           
            end        
        end
    end
    logic [15:0] led2;
    logic live_cpu_stores;
    always_ff @(posedge clk) begin
        if(rst)
            live_cpu_stores <= '0;
        else if(num_elems != '0 && new_inst_valid)
            live_cpu_stores <= |(num_elems - 1);
        else
            live_cpu_stores <= |num_elems;
    end
    // ============================================
    // GPU Cluster System
    // ============================================
    gpuClusterSystem #(
        .NUM_CORES(NUM_CORES)
    ) gpuClusterSystem_inst (
        .clk(clk),
        .rst(rst),

        .loadsEnabled(loadsEnabled),
        .storesEnabled(storesEnabled),

        // Memory interfaces
        .ddr3ReadyForLoad(ddr3ReadyForLoad),
        .ddr3ReadyForStore(ddr3ReadyForStore),
        
        .loadedDDR3Value(loadedDDR3Value),
        .loadedSharedValue(loadedSharedValue),
        .loadDDR3Returned(loadDDR3Returned),

        .loadAddress(loadAddress),
        .ddr3StartLoad(ddr3StartLoad),
        .sharedStartLoad(sharedStartLoad),
        .storeAddress(storeAddress),
        .storeValue(storeValue),
        .storeByteEnable(storeByteEnable),
        .sharedStartStore(sharedStartStore),
        .ddr3StartStore(ddr3StartStore),
        
        .new_inst(new_inst),
        .new_inst_valid(new_inst_valid && num_elems == '0 && new_inst[31:28] != 4'b1101),
        .fetch_queue_full(fetch_queue_full),
        
        .live_cpu_stores(live_cpu_stores),
        
        .ibuf_fill(ibuf_fill),
        .led(led)
    );

    // ============================================
    // Shared Memory Module
    // ============================================
    sharedMemoryModule sharedMemoryModule_inst (
        .clk(clk),
        .rst(rst),

        .storeAddress(storeAddress),
        .storeValue(storeValue),
        .storeByteEnable(storeByteEnable),
        .sharedStartStore(sharedStartStore),

        .cpuStoreAddress(cpu_side_address),
        .cpuStoreValue(new_inst),
        .doCpuStore(num_elems != '0 && new_inst_valid),
        .fill(cpu_write_fill_level),
        .freeze(loadDDR3Returned),

        .loadAddress(loadAddress),
        .sharedStartLoad(sharedStartLoad),

        .loadedSharedValue(loadedSharedValue)
    );

    // ============================================
    // DDR3 Cross-Domain Interface
    // ============================================
    memCrossDomain #(
        .NUM_CORES(NUM_CORES)
    ) memCrossDomain_inst (
        .clk(clk),
        .rst(rst),

        // To DDR3 controller
        .cacheDataWrite(cacheDataWrite),
        .cacheAddress(cacheAddress),
        .cacheDataRead(cacheDataRead),
        .cacheEnableGlobal(cacheEnableGlobal),
        .cacheEnableGlobalWrite(cacheEnableGlobalWrite),
        .cacheWriteBytes(cacheWriteBytes),
        .cacheFinishedRead(cacheFinishedRead),
        .memControllerReady(memControllerReady), 


        // Core enable signals (unused here - tie low)
        .enableCoreStores(storesEnabled),
        .enableCoreLoads(loadsEnabled),

        // From GPU cluster
        .loadAddress(loadAddress),
        .ddr3StartLoad(ddr3StartLoad),
        .ddr3ReadyForLoad(ddr3ReadyForLoad),
        .sharedStartLoad(sharedStartLoad), // passthrough for handshake

        .loadedDDR3Value(loadedDDR3Value),
        .loadReturned(loadDDR3Returned),

        .storeAddress(storeAddress),
        .storeValue(storeValue),
        .storeByteEnable(storeByteEnable),
        .ddr3ReadyForStore(ddr3ReadyForStore),
        .ddr3StartStore(ddr3StartStore),
        .debug(debug)
    );

endmodule