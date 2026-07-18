module gpuClusterSystem #(
    parameter NUM_CORES = 16,
    parameter QUEUE_SIZE = 1024
)(
    input  logic        clk,
    input  logic        rst,
 
    // Frontend
    input  logic [31:0] new_inst,
    input  logic        new_inst_valid,
    output logic        fetch_queue_full,
    
    output logic [NUM_CORES - 1 : 0] storesEnabled,
    output logic [NUM_CORES - 1 : 0] loadsEnabled,
    // External DDR3/shared memory interfaces
    input  logic        ddr3ReadyForLoad,
    input  logic        ddr3ReadyForStore,
    input  logic [127:0] loadedDDR3Value,
    input  logic [127:0] loadedSharedValue,
    input  logic         loadDDR3Returned,
    output logic [31:0]  loadAddress,
    output logic         ddr3StartLoad,
    output logic         sharedStartLoad,
    output logic [31:0]  storeAddress,
    output logic [127:0] storeValue,
    output logic [15:0]  storeByteEnable,
    output logic         sharedStartStore,
    output logic         ddr3StartStore,
    input logic live_cpu_stores,
    output logic [31:0] ibuf_fill,
    output logic [15:0] led
);

    // -------------------------------
    // Internal signals
    // -------------------------------
    logic [NUM_CORES-1:0][31:0] div_reg0, div_reg1;
    logic [NUM_CORES-1:0]       should_divide;
    logic [NUM_CORES-1:0][31:0] div_result;
    logic [NUM_CORES-1:0]       div_finished;

    logic [NUM_CORES-1:0][31:0] store_addr;
    logic [NUM_CORES-1:0][31:0] store_value;
    logic [NUM_CORES-1:0][3:0]  store_we;
    logic [NUM_CORES-1:0]       store_enable;
    logic [NUM_CORES-1:0]       store_finished;

    logic [NUM_CORES-1:0][31:0] load_addr;
    logic [NUM_CORES-1:0]       should_load;
    logic [NUM_CORES-1:0]       load_finished, load_acknowledged;
    logic [NUM_CORES-1:0][31:0] load_value;
    
    logic [NUM_CORES-1:0][7:0] load_command_id, load_finished_id;
    // -------------------------------
    // Instantiate GPU Core Cluster
    // -------------------------------
    gpuCoreCluster #(
        .NUM_CORES(NUM_CORES),
        .QUEUE_SIZE(QUEUE_SIZE)
    ) cluster (
        .clk(clk),
        .rst(rst),

        .new_inst(new_inst),
        .new_inst_valid(new_inst_valid),
        .fetch_queue_full(fetch_queue_full),

        // Division interface
        .div_reg0(div_reg0),
        .div_reg1(div_reg1),
        .should_divide(should_divide),
        .div_result(div_result),
        .div_finished(div_finished),

        // Store interface
        .store_addr(store_addr),
        .store_value(store_value),
        .store_we(store_we),
        .store_enable(store_enable),
        .store_finished(store_finished),

        // Load interface
        .load_addr(load_addr),
        .load_finished(load_finished),
        .load_value(load_value),
        .should_load(should_load),
        .load_acknowledged(load_acknowledged),
        .load_command_id(load_command_id),
        .load_finished_id(load_finished_id),
        .live_cpu_stores(live_cpu_stores),
        .ibuf_fill(ibuf_fill),
        .led(led)
    );

    integer i;
    logic [NUM_CORES - 1 : 0] msbStoreAddress, msbLoadAddress;
    always_comb begin
        for(i = 0; i < NUM_CORES; i++) begin
            msbStoreAddress[i] = store_addr[i][31];
            msbLoadAddress[i] = load_addr[i][31];
        end
    end
    assign storesEnabled = store_enable & ~msbStoreAddress;
    assign loadsEnabled = should_load & ~msbLoadAddress;
    // -------------------------------
    // Instantiate Division Units
    // -------------------------------
    divisonUnits #(
        .NUM_CORES(NUM_CORES),
        .DIVIDERS(1)
    ) divUnits (
        .clk(clk),
        .rst(rst),
        .inputA(div_reg0),
        .inputB(div_reg1),
        .outputC(div_result),
        .enableDivide(should_divide),
        .coreDivideFinished(div_finished)
    );

    // -------------------------------
    // Instantiate Loader
    // -------------------------------
    loader #(
        .NUM_CORES(NUM_CORES)
    ) loadUnit (
        .clk(clk),
        .rst(rst),
        
        .coreAddresses(load_addr),
        .enableLoad(should_load),
        .coreValues(load_value),
        .finishedLoad(load_finished),

        .loadAddress(loadAddress),
        .ddr3StartLoad(ddr3StartLoad),
        .ddr3ReadyForLoad(ddr3ReadyForLoad),
        .sharedStartLoad(sharedStartLoad),

        .loadedDDR3Value(loadedDDR3Value),
        .loadDDR3Returned(loadDDR3Returned),
        .loadedSharedValue(loadedSharedValue),
        
        .load_acknowledged(load_acknowledged),
        .load_command_id(load_command_id),
        .load_finished_id(load_finished_id)
    );
    // -------------------------------
    // Instantiate Storer
    // -------------------------------
    storer #(
        .NUM_CORES(NUM_CORES)
    ) storeUnit (
        .clk(clk),
        .rst(rst),
        .coreAddresses(store_addr),
        .enableStore(store_enable),
        .coreByteEnable(store_we),
        .coreValues(store_value),
        .finishedStore(store_finished),

        .storeAddress(storeAddress),
        .storeValue(storeValue),
        .storeByteEnable(storeByteEnable),
        .ddr3ReadyForStore(ddr3ReadyForStore),
        .sharedStartStore(sharedStartStore),
        .ddr3StartStore(ddr3StartStore),
        .led()
    );
//    always_ff @(posedge clk) begin
//        if(rst)
//            led <= '0;
//        else if (ddr3StartStore)
//            led <= led + storeByteEnable[0] + storeByteEnable[4] + storeByteEnable[8] + storeByteEnable[12];
    
//    end
endmodule
