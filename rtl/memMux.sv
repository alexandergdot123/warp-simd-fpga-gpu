module memCrossDomain #(parameter NUM_CORES = 16)(
    input logic clk,
    input logic rst,

    //to the memory controller
    output logic [127:0] cacheDataWrite,
    output logic [26:0] cacheAddress,
    input logic [127:0] cacheDataRead,
    output logic cacheEnableGlobal,
    output logic cacheEnableGlobalWrite,
    output logic [15:0] cacheWriteBytes,
    input logic cacheFinishedRead,
    input logic memControllerReady, 
    
    input logic [NUM_CORES - 1 : 0] enableCoreStores,
    input logic [NUM_CORES - 1 : 0] enableCoreLoads,

    input logic [31:0] loadAddress,
    input logic ddr3StartLoad,
    output logic ddr3ReadyForLoad,
    input logic sharedStartLoad,

    output logic [127:0] loadedDDR3Value,
    output logic loadReturned,

    input logic [31:0] storeAddress,
    input logic [127:0] storeValue,
    input logic [15:0] storeByteEnable,
    output logic ddr3ReadyForStore,
    input logic ddr3StartStore,
    output logic [3:0] debug
);
    logic loadActive, storeActive;
    assign loadActive = |enableCoreLoads;
    assign storeActive = |enableCoreStores;
    logic enablingLoads, holdingCommand;
    assign debug[3] = enablingLoads;
    assign debug[2] = holdingCommand;
    assign debug[1] = memControllerReady;
    assign debug[0] = loadActive;
    always_ff @(posedge clk) begin

        if(holdingCommand)
            enablingLoads <= enablingLoads;
        else if ((enablingLoads && loadActive) || (~enablingLoads && storeActive))
            enablingLoads <= enablingLoads;
        else if((~enablingLoads && loadActive) || (enablingLoads && storeActive)) 
            enablingLoads <= ~enablingLoads;
        else if(~loadActive && ~storeActive)
            enablingLoads <= '1;


        if(rst) begin
            holdingCommand <= '0;
        end
        else begin
            if(holdingCommand) begin
                if(enablingLoads && ~ddr3StartLoad && cacheEnableGlobal)
                    holdingCommand <= '0;
                if(~enablingLoads && ~ddr3StartStore && cacheEnableGlobal)
                    holdingCommand <= '0;
            end
            else begin
                if(enablingLoads && ddr3StartLoad)
                    holdingCommand <= '1;
                if(~enablingLoads && ddr3StartStore)
                    holdingCommand <= '1;
            end

        end
        
        
        if(ddr3StartStore) begin
            cacheAddress <= storeAddress;
            cacheDataWrite <= storeValue;
            cacheWriteBytes <= storeByteEnable;
        end
        if(ddr3StartLoad) begin
            cacheAddress <= loadAddress;
        end
        
        
        if(rst)
            loadReturned <= '0;
        else 
            loadReturned <= cacheFinishedRead;
        
        loadedDDR3Value <= cacheDataRead;
    
    end

    always_comb begin
        cacheEnableGlobal = memControllerReady && holdingCommand;
        cacheEnableGlobalWrite = ~enablingLoads;
        ddr3ReadyForStore = ~enablingLoads && (~holdingCommand || cacheEnableGlobal); 
        ddr3ReadyForLoad = enablingLoads && (~holdingCommand || cacheEnableGlobal); 
    end
endmodule




module sharedMemoryModule #(parameter Bytes = 1024)(
    input logic clk,
    input logic rst,

    input logic [31:0] storeAddress,
    input logic [127:0] storeValue,
    input logic [15:0] storeByteEnable,
    input logic sharedStartStore,

    input logic [31:0] cpuStoreAddress,
    input logic [31:0] cpuStoreValue,
    input logic doCpuStore,
    output logic [7:0] fill,
    input logic freeze, 
    input logic [31:0] loadAddress,
    input logic sharedStartLoad,

    output logic [127:0] loadedSharedValue,
    output logic sharedLoadReturned
);
    logic cpu_store_ready, pull_cpu_store_from_fifo, activate_cpu_store;
    logic [8:0] head, tail;
    logic [31:0] cpuAddressToStore, cpuValueToStore, cpuAddressToStoreOut, cpuValueToStoreOut;
    
    logic [31:0] storeAddressDelayed;
    logic [127:0] storeValueDelayed;
    logic [15:0] storeByteEnableDelayed;
    logic sharedStartStoreDelayed;
    logic [31:0] frozenLoadAddress, sharedMemAddressIn;
    assign sharedMemAddressIn = (freeze && ~sharedStartLoad) ? frozenLoadAddress : loadAddress;
    logic oldDoCpuStore;
    always_ff @(posedge clk) begin
        storeAddressDelayed <= storeAddress;
        storeValueDelayed <= storeValue;
        sharedStartStoreDelayed <= sharedStartStore;
        storeByteEnableDelayed <= storeByteEnable;
        
        if(sharedStartLoad)
            frozenLoadAddress <= loadAddress;
        
        
        if(rst) begin
            head <= '0;
            tail <= '0;    
            cpu_store_ready <= '0;
            oldDoCpuStore <= '0;
        end
        else begin
            if(oldDoCpuStore)
                tail <= tail + 1;
                
            if(pull_cpu_store_from_fifo) begin
                head <= head + 1;
                cpuAddressToStore <= cpuAddressToStoreOut;
                cpuValueToStore <= cpuValueToStoreOut;
                cpu_store_ready <= '1;
            end
            else if (activate_cpu_store) begin
                cpu_store_ready <= '0;
            end        
            oldDoCpuStore <= doCpuStore;

        end
    end
    assign pull_cpu_store_from_fifo = fill != 0 && (~cpu_store_ready || activate_cpu_store);
    assign fill = tail - head;
    assign activate_cpu_store = ~sharedStartStoreDelayed && cpu_store_ready;
    genvar i;
    generate
        for(i = 0; i < 4; i++) begin
            sharedMem sharedMemSlice (
                .clka   (clk),
                .ena    ('1),
                .wea    (({4{sharedStartStoreDelayed}} & storeByteEnableDelayed[4*i +: 4]) | {4{(activate_cpu_store && cpuAddressToStore[1:0] == i)}}), 
                .addra  (activate_cpu_store ? cpuAddressToStore[30:2] : storeAddressDelayed[30:3]),
                .dina   (activate_cpu_store ? cpuValueToStore : storeValueDelayed[32 * i +: 32]),

                .clkb   (clk),
                .enb    ('1),
                .addrb  (sharedMemAddressIn[30:3]),
                .doutb  (loadedSharedValue[32*i +: 32])
            );

        end

    endgenerate
    always_ff @(posedge clk) begin
        if(rst)
            sharedLoadReturned <= '0;
        else
            sharedLoadReturned <= (freeze) ? (sharedLoadReturned || sharedStartLoad) : sharedStartLoad;

    end
    cpuDataQueue cpuDataQueueInst (
        .clka   (clk),
        .ena    (doCpuStore),
        .wea    ('1),
        .addra  (tail),
        .dina   (cpuStoreValue),

        .clkb   (clk),
        .enb    ('1),
        .addrb  (head),
        .doutb  (cpuValueToStoreOut)
    );
    cpuAddressQueue cpuAddressQueueInst (
        .clka   (clk),
        .ena    (doCpuStore),
        .wea    ('1),
        .addra  (tail),
        .dina   (cpuStoreAddress),

        .clkb   (clk),
        .enb    ('1),
        .addrb  (head),
        .doutb  (cpuAddressToStoreOut)
    );
endmodule