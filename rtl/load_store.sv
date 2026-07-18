module loader #(
    parameter NUM_CORES = 16
)(
    input logic clk,
    input logic rst,

    input logic [NUM_CORES - 1 : 0][31:0] coreAddresses,
    input logic [NUM_CORES - 1 : 0] enableLoad,
    output logic [NUM_CORES - 1 : 0][31:0] coreValues,
    output logic [NUM_CORES - 1 : 0] finishedLoad,

    output logic [31:0] loadAddress,
    output logic ddr3StartLoad,
    input logic ddr3ReadyForLoad,
    output logic sharedStartLoad,


    input logic [127:0] loadedDDR3Value,
    input logic loadDDR3Returned,
    input logic [127:0] loadedSharedValue,
    
    input logic [NUM_CORES-1:0][7:0] load_command_id,
    output logic [NUM_CORES-1:0][7:0] load_finished_id,
    output logic [NUM_CORES-1:0] load_acknowledged
);
    logic doLoad, loadSharedReturned;
    logic [127:0] rearrangedReturnLoadValue, loadedValue;
    logic [1:0] returnedLoadAddressAlignment, returnedLoadAddressAlignmentShared, returnedLoadAddressAlignmentDDR3, 
        returnedCoreLoadQuantity, returnedCoreLoadQuantityShared, returnedCoreLoadQuantityDDR3, commandLoadAddressAlignment, commandCoreLoadQuantity;
    logic [$clog2(NUM_CORES) - 1 : 0] returnedLoadPtr,returnedLoadPtrShared, returnedLoadPtrDDR3;
    logic [NUM_CORES - 1:0] commandPtrPlusOne, commandPtrPlusTwo, commandPtrPlusThree, returnedLoadPtrPlusOne, returnedLoadPtrPlusTwo, returnedLoadPtrPlusThree, addressesPlusOne;
    logic [$clog2(NUM_CORES) - 1 : 0] commandPtr;
    logic [31:0] register_ids_in, register_ids_out, register_ids_outShared, register_ids_outDDR3;
    assign commandPtrPlusOne = (commandPtr + 1) % NUM_CORES;
    assign commandPtrPlusTwo = (commandPtr + 2) % NUM_CORES;
    assign commandPtrPlusThree = (commandPtr + 3) % NUM_CORES;
    assign returnedLoadPtrPlusOne = (returnedLoadPtr + 1) % NUM_CORES;
    assign returnedLoadPtrPlusTwo = (returnedLoadPtr + 2) % NUM_CORES;
    assign returnedLoadPtrPlusThree = (returnedLoadPtr + 3) % NUM_CORES;

    always_comb begin
        loadedValue = (loadDDR3Returned) ? loadedDDR3Value : loadedSharedValue;
        
        returnedLoadPtr = loadDDR3Returned ? returnedLoadPtrDDR3 : returnedLoadPtrShared;
        returnedLoadAddressAlignment = loadDDR3Returned ? returnedLoadAddressAlignmentDDR3 : returnedLoadAddressAlignmentShared;
        returnedCoreLoadQuantity = loadDDR3Returned ? returnedCoreLoadQuantityDDR3 : returnedCoreLoadQuantityShared;
        register_ids_out = loadDDR3Returned ? register_ids_outDDR3 : register_ids_outShared;
        
        load_acknowledged = '0;
        for(integer i = 0; i < NUM_CORES; i++) begin
            if(doLoad && commandPtr == i)
                load_acknowledged[i] = '1;
            else if (doLoad && commandPtrPlusOne == i && (coreAddresses[commandPtrPlusOne][1:0] != 2'b00 && addressesPlusOne[commandPtr] && enableLoad[commandPtrPlusOne]))
                load_acknowledged[i] = '1;
            else if (doLoad && commandPtrPlusTwo == i && (coreAddresses[commandPtrPlusOne][1:0] != 2'b00 && addressesPlusOne[commandPtr] && enableLoad[commandPtrPlusOne]) 
                && (coreAddresses[commandPtrPlusTwo][1:0] != 2'b00 && addressesPlusOne[commandPtrPlusOne] && enableLoad[commandPtrPlusTwo]))
                load_acknowledged[i] = '1;
            else if (doLoad && commandPtrPlusThree == i && (coreAddresses[commandPtrPlusOne][1:0] != 2'b00 && addressesPlusOne[commandPtr] && enableLoad[commandPtrPlusOne]) 
                && (coreAddresses[commandPtrPlusTwo][1:0] != 2'b00 && addressesPlusOne[commandPtrPlusOne] && enableLoad[commandPtrPlusTwo]) && 
                (coreAddresses[commandPtrPlusThree][1:0] != 2'b00 && addressesPlusOne[commandPtrPlusTwo] && enableLoad[commandPtrPlusThree]))
                load_acknowledged[i] = '1;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            loadSharedReturned <= '0;
        end
        else begin
            if(~loadDDR3Returned || ~loadSharedReturned)
                loadSharedReturned <= sharedStartLoad;
        end
        


        returnedLoadAddressAlignmentShared <= (loadDDR3Returned && loadSharedReturned) ? returnedLoadAddressAlignmentShared : commandLoadAddressAlignment;
        returnedLoadPtrShared <= (loadDDR3Returned && loadSharedReturned) ? returnedLoadPtrShared : commandPtr;
        returnedCoreLoadQuantityShared <= (loadDDR3Returned && loadSharedReturned) ? returnedCoreLoadQuantityShared : commandCoreLoadQuantity;
        register_ids_outShared <= (loadDDR3Returned && loadSharedReturned) ? register_ids_outShared : register_ids_in;
    end

    always_comb begin
        for(integer i = 0; i < NUM_CORES; i++)
            addressesPlusOne[i] = coreAddresses[i] + 'd1 == coreAddresses[(i + 1)% NUM_CORES] && enableLoad[i] && enableLoad[(i+1) % NUM_CORES] && coreAddresses[(i + 1)% NUM_CORES][1:0] != 2'b00;
    end

    always_comb begin
        case(returnedLoadAddressAlignment)
            2'b00: rearrangedReturnLoadValue = loadedValue;
            2'b01: rearrangedReturnLoadValue = {32'hXXXXXXXX, loadedValue[127:32]};
            2'b10: rearrangedReturnLoadValue = {64'hXXXXXXXX, loadedValue[127:64]};
            2'b11: rearrangedReturnLoadValue = {96'hXXXXXXXX, loadedValue[127:96]};
        endcase
    end

    assign doLoad = ddr3StartLoad || sharedStartLoad;

    always_comb begin
        loadAddress = {coreAddresses[commandPtr][30:2], 3'b000}; //4 Bytes in a 32 bit load, 4 cores in a bus load
        commandLoadAddressAlignment = coreAddresses[commandPtr][1:0];
        if(addressesPlusOne[commandPtr]) begin
            if(addressesPlusOne[commandPtrPlusOne]) begin
                if(addressesPlusOne[commandPtrPlusTwo])
                    commandCoreLoadQuantity = 2'b11;
                else 
                    commandCoreLoadQuantity = 2'b10;
            end
            else
                commandCoreLoadQuantity = 2'b01;
        end
        else
            commandCoreLoadQuantity = 2'b00;

        ddr3StartLoad = ddr3ReadyForLoad && enableLoad[commandPtr] && ~coreAddresses[commandPtr][31];
        sharedStartLoad = ~(loadDDR3Returned && loadSharedReturned) && enableLoad[commandPtr] && coreAddresses[commandPtr][31];
        register_ids_in[7:0] = load_command_id[commandPtr];
        register_ids_in[15:8] = load_command_id[commandPtrPlusOne];
        register_ids_in[23:16] = load_command_id[commandPtrPlusTwo];
        register_ids_in[31:24] = load_command_id[commandPtrPlusThree];
    end 

    always_ff @(posedge clk) begin
        coreValues <= 'X;
        coreValues[returnedLoadPtr] <= rearrangedReturnLoadValue[31:0];
        coreValues[returnedLoadPtrPlusOne] <= rearrangedReturnLoadValue[63:32];
        coreValues[returnedLoadPtrPlusTwo] <= rearrangedReturnLoadValue[95:64];
        coreValues[returnedLoadPtrPlusThree] <= rearrangedReturnLoadValue[127:96];
        
        finishedLoad <= '0;
        finishedLoad[returnedLoadPtr] <= (loadDDR3Returned || loadSharedReturned); 
        finishedLoad[returnedLoadPtrPlusOne] <= (loadDDR3Returned || loadSharedReturned) && returnedCoreLoadQuantity != 2'b00; //off if >0
        finishedLoad[returnedLoadPtrPlusTwo] <= (loadDDR3Returned || loadSharedReturned)  && returnedCoreLoadQuantity[1]; //off if 1 or 0
        finishedLoad[returnedLoadPtrPlusThree] <= (loadDDR3Returned || loadSharedReturned) && returnedCoreLoadQuantity == 2'b11; //off is 2 or 1 or 0
        
        load_finished_id <= 'x;
        load_finished_id[returnedLoadPtr] <= register_ids_out[7:0];
        load_finished_id[returnedLoadPtrPlusOne] <= register_ids_out[15:8];
        load_finished_id[returnedLoadPtrPlusTwo] <= register_ids_out[23:16];
        load_finished_id[returnedLoadPtrPlusThree] <= register_ids_out[31:24];
        
        if(rst)
            commandPtr <= '0;
        else begin
            if((coreAddresses[commandPtrPlusOne][1:0] != 2'b00 && addressesPlusOne[commandPtr]) || ~enableLoad[commandPtrPlusOne] && doLoad) begin
                if((coreAddresses[commandPtrPlusTwo][1:0] != 2'b00 && addressesPlusOne[commandPtrPlusOne]) || ~enableLoad[commandPtrPlusTwo]) begin
                    if((coreAddresses[commandPtrPlusThree][1:0] != 2'b00 && addressesPlusOne[commandPtrPlusTwo]) || ~enableLoad[commandPtrPlusThree])
                        commandPtr <= (commandPtr + 4) % NUM_CORES;
                    else 
                        commandPtr <= (commandPtr + 3) % NUM_CORES;
                end
                else
                    commandPtr <= (commandPtr + 2) % NUM_CORES;
            end
            else
                commandPtr <= (commandPtr + 1) % NUM_CORES;
        end

    end

    fifo_generator_1 ddr3Fifo (
        .clk(clk),
        .srst(rst),

        .wr_en(ddr3StartLoad),
        .din({commandPtr, commandLoadAddressAlignment, commandCoreLoadQuantity, register_ids_in}),

        .rd_en(loadDDR3Returned),
        .dout({returnedLoadPtrDDR3, returnedLoadAddressAlignmentDDR3, returnedCoreLoadQuantityDDR3, register_ids_outDDR3})
    );

endmodule



module storer #(
    parameter NUM_CORES = 16
)(
    input logic clk,
    input logic rst,

    input logic [NUM_CORES - 1 : 0][31:0] coreAddresses,
    input logic [NUM_CORES - 1 : 0] enableStore,
    input logic [NUM_CORES - 1 : 0][3:0] coreByteEnable,
    input logic [NUM_CORES - 1 : 0][31:0] coreValues,
    output logic [NUM_CORES - 1 : 0] finishedStore,

    output logic [31:0] storeAddress,
    output logic [127:0] storeValue,
    output logic [15:0] storeByteEnable,
    input logic ddr3ReadyForStore,
    output logic sharedStartStore,
    output logic ddr3StartStore,
    output logic [15:0] led

);
    logic doStore;
    logic [127:0] coalescedValue;
    logic [1:0] addressAlignment, commandCoreStoreQuantity;
    logic [$clog2(NUM_CORES) - 1 : 0] commandPtrPlusOne, commandPtrPlusTwo, commandPtrPlusThree, commandPtr;
    logic [NUM_CORES - 1:0]  addressesPlusOne;
    logic [15:0] rearrangingByteEnable;
    assign commandPtrPlusOne = (commandPtr + 1) % NUM_CORES;
    assign commandPtrPlusTwo = (commandPtr + 2) % NUM_CORES;
    assign commandPtrPlusThree = (commandPtr + 3) % NUM_CORES;

    always_comb begin
        for(integer i = 0; i < NUM_CORES; i++)
            addressesPlusOne[i] = coreAddresses[i] + 'd1 == coreAddresses[(i + 1)% NUM_CORES] && coreAddresses[(i + 1)% NUM_CORES][1:0] != 2'b00 && enableStore[i] && enableStore[(i + 1)% NUM_CORES];

    end

    always_comb begin
        coalescedValue[31:0] = coreValues[commandPtr];
        coalescedValue[63:32] = coreValues[commandPtrPlusOne];
        coalescedValue[95:64] = coreValues[commandPtrPlusTwo];
        coalescedValue[127:96] = coreValues[commandPtrPlusThree];

        addressAlignment = coreAddresses[commandPtr][1:0];

        case(addressAlignment)
            2'b00: storeValue = coalescedValue;
            2'b01: storeValue = {coalescedValue[95:0], {32{1'b1}}};
            2'b10: storeValue = {coalescedValue[63:0], {64{1'b1}}};
            2'b11: storeValue = {coalescedValue[31:0], {96{1'b1}}};
        endcase

        rearrangingByteEnable[3:0] = coreByteEnable[commandPtr] & {4{enableStore[commandPtr]}};
        rearrangingByteEnable[7:4] = coreByteEnable[commandPtrPlusOne] & {4{commandCoreStoreQuantity != 2'b00}};
        rearrangingByteEnable[11:8] = coreByteEnable[commandPtrPlusTwo] & {4{commandCoreStoreQuantity[1]}};
        rearrangingByteEnable[15:12] = coreByteEnable[commandPtrPlusThree] & {4{commandCoreStoreQuantity == 2'b11}};

        case(addressAlignment)
            2'b00: storeByteEnable = rearrangingByteEnable;
            2'b01: storeByteEnable = {rearrangingByteEnable[11:0],4'h0};
            2'b10: storeByteEnable = {rearrangingByteEnable[7:0],8'h00};
            2'b11: storeByteEnable = {rearrangingByteEnable[3:0],12'h000};
        endcase


    end



    always_comb begin
        storeAddress = {coreAddresses[commandPtr][30:2], 3'b000}; //4 Bytes in a 32 bit load, 4 cores in a bus load
        if(addressesPlusOne[commandPtr]) begin
            if(addressesPlusOne[commandPtrPlusOne]) begin
                if(addressesPlusOne[commandPtrPlusTwo])
                    commandCoreStoreQuantity = 2'b11;
                else 
                    commandCoreStoreQuantity = 2'b10;
            end
            else
                commandCoreStoreQuantity = 2'b01;
        end
        else
            commandCoreStoreQuantity = 2'b00;


        ddr3StartStore = ddr3ReadyForStore && enableStore[commandPtr] && ~coreAddresses[commandPtr][31];
        sharedStartStore = enableStore[commandPtr] && coreAddresses[commandPtr][31];
    end 
    assign doStore = ddr3StartStore || sharedStartStore;
    integer andrew;
    always_ff @(posedge clk) begin
        if(rst)
            commandPtr <= '0;
        else begin
            if(addressesPlusOne[commandPtr] || ~enableStore[commandPtrPlusOne]) begin
                if(addressesPlusOne[commandPtrPlusOne] || ~enableStore[commandPtrPlusTwo]) begin
                    if(addressesPlusOne[commandPtrPlusTwo] || ~enableStore[commandPtrPlusThree])
                        commandPtr <= (commandPtr + 4) % NUM_CORES;
                    else 
                        commandPtr <= (commandPtr + 3) % NUM_CORES;
                end
                else
                    commandPtr <= (commandPtr + 2) % NUM_CORES;
            end
            else
                commandPtr <= (commandPtr + 1) % NUM_CORES;
        end
        if(rst) begin
            led <= '0;
        end
        else begin
            for(andrew = 6; andrew < NUM_CORES; andrew++) begin
                if(coreAddresses[andrew] >= 'd38400 && enableStore[andrew])
                    led[andrew] <= '1;            
            end
            if(ddr3StartStore && storeAddress >= 'd76800)
                led[14] <= '1;
        end


    end

    always_comb begin

        finishedStore = '0;
        finishedStore[commandPtr] = doStore;
        finishedStore[commandPtrPlusOne] = doStore && commandCoreStoreQuantity != 2'b00;
        finishedStore[commandPtrPlusTwo] = doStore && commandCoreStoreQuantity[1];
        finishedStore[commandPtrPlusThree] = doStore && commandCoreStoreQuantity == 2'b11;
    end

endmodule


//module storer #(
//    parameter NUM_CORES = 16
//)(
//    input logic clk,
//    input logic rst,

//    input logic [NUM_CORES - 1 : 0][31:0] coreAddresses,
//    input logic [NUM_CORES - 1 : 0] enableStore,
//    input logic [NUM_CORES - 1 : 0][3:0] coreByteEnable,
//    input logic [NUM_CORES - 1 : 0][31:0] coreValues,
//    output logic [NUM_CORES - 1 : 0] finishedStore,

//    output logic [31:0] storeAddress,
//    output logic [127:0] storeValue,
//    output logic [15:0] storeByteEnable,
//    input logic ddr3ReadyForStore,
//    output logic sharedStartStore,
//    output logic ddr3StartStore

//);
//    logic [1:0] addressAlignment;
//    logic [$clog2(NUM_CORES) - 1 : 0]  commandPtr;
//    always_ff @(posedge clk) begin
//        if(rst)
//            commandPtr <= '0;
//        else
//            commandPtr <= (commandPtr + 1) % NUM_CORES;
//    end
//    assign addressAlignment = coreAddresses[commandPtr][1:0];
//    assign ddr3StartStore = enableStore[commandPtr] && ~coreAddresses[commandPtr][31] && ddr3ReadyForStore;
//    assign sharedStartStore = enableStore[commandPtr] && coreAddresses[commandPtr][31];
//    always_comb begin
//        finishedStore = '0;
//        finishedStore[commandPtr] = ddr3StartStore || sharedStartStore;
//    end
//    assign storeAddress = {coreAddresses[commandPtr][30:2], 3'b000};
//    assign storeValue = {4{coreValues[commandPtr]}};
//    assign storeByteEnable = {coreByteEnable[commandPtr] & {4{addressAlignment == 2'b11}}, coreByteEnable[commandPtr] & {4{addressAlignment == 2'b10}}, 
//        coreByteEnable[commandPtr] & {4{addressAlignment == 2'b01}}, coreByteEnable[commandPtr] & {4{addressAlignment == 2'b00}}};

//endmodule