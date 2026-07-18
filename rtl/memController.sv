
module memoryController(
    input logic clk,
    input logic reset,

    //from the cache
    input logic [127:0] cacheDataWrite,
    input logic [26:0] cacheAddress,
    output logic [127:0] cacheDataRead,
    input logic cacheEnableGlobal,
    input logic cacheEnableGlobalWrite,
    input logic [15:0] cacheWriteBytes,
    output logic cacheFinishedRead,
    output logic cacheFinishedCommand,

    //from the vga controller
    input logic [9:0] drawX,
    input logic [9:0] drawY,
    output logic frame,
    // input logic chooseBuffer,

    //obvious
    output logic [7:0] red,
    output logic [7:0] green,
    output logic [7:0] blue,

    //talks to the ddr3
    output logic [26:0] alexAddress,
    input logic [127:0] alexReadData,
    output logic [127:0] alexWriteData,
    output logic [1:0] alexMemEnable,
    output logic [15:0] alexWriteBytes,
    input logic alexFinishedMemAction,
    input logic alexCommandAcknowledged,
    output logic alexNewCommand
);
/*
    ALL OF THE SAVE VALUES MUST BE SAVED IN 100MHZ, NOT 200MHZ!!!!

*/
    logic processingAlexCommand;
    assign cacheDataRead = alexReadData;

    logic [9:0] writeCounter;
    logic [9:0] readCounter;
    logic [19:0] rowColIndexWire, rowColIndexReg, frozenRowColIndex, addFrameBuffer, rowColPlusFrameBuf;    
    logic [127:0] pixelsOut;
    logic [31:0] pixel;    
    logic [26:0] vgaAddress;

    logic [7:0] outstandingMemRequests;
    logic vgaLoadWhenReady, frameBufIndex;
    logic holdingCommandSignalHigh, oldAlexCommandAcknowledged;
    logic pipeline_modulo, oldDrawYExceed;
    assign rowColIndexWire = drawX + drawY * 640;
    assign addFrameBuffer = {20{frameBufIndex}} & 20'd307200;
    assign frame = frameBufIndex;
    typedef enum {
        readVGA,
        waitVGA,
        
        sendCore,
        waitCore
    } memControllerState; //These are the different values that the state of the controller can take on

    memControllerState curState;
    
    

    
    
    always_ff @(posedge clk) begin
        if(reset) begin
            rowColIndexReg <= 0;
            curState <= sendCore;
            readCounter <= 0;
            writeCounter <= 0;
            frozenRowColIndex <= 0;
            vgaLoadWhenReady <= 0;
            outstandingMemRequests <= '0;
            frameBufIndex <= '0;
            pipeline_modulo <= '0;
            oldDrawYExceed <= '0;
            processingAlexCommand <= '0;
        end
        else begin
            rowColIndexReg <= rowColIndexWire;
            case(curState)
                readVGA: curState <= (readCounter == 10'b1000000000) ? waitVGA : readVGA;
                waitVGA: curState <= (writeCounter == 10'b1000000000) ? sendCore : waitVGA;
                sendCore: curState <= (vgaLoadWhenReady) ? waitCore : sendCore;
                waitCore: curState <= (outstandingMemRequests == '0 && ~processingAlexCommand) ? readVGA : waitCore;            
            endcase            
            if(curState == readVGA) begin
                if(alexCommandAcknowledged) begin
                    readCounter <= readCounter + 1; //increment the readCounter each time a new command is acknowledged/received
                end
                
                if(alexFinishedMemAction) begin
                    writeCounter <= writeCounter + 1; //increment the writeCounter every time a read has been finished
                end

                outstandingMemRequests <= '0;
                processingAlexCommand <= '0;
            end
            else if (curState == waitVGA) begin
                if(alexFinishedMemAction) begin
                    writeCounter <= writeCounter + 1; //increment the writeCounter every time a read has been finished
                end
                processingAlexCommand <= '0;

                outstandingMemRequests <= '0;
            end
            else if (curState == sendCore) begin //when the state is sending the commands from the cores
                if(alexCommandAcknowledged && alexMemEnable == 2'b01 && ~alexFinishedMemAction)
                    outstandingMemRequests <= outstandingMemRequests + 1;
                else if(~(alexCommandAcknowledged && alexMemEnable == 2'b01) && alexFinishedMemAction)
                    outstandingMemRequests <= outstandingMemRequests - 1;

                readCounter <= '0;
                writeCounter <= '0;
                processingAlexCommand <= cacheEnableGlobal && ~(vgaLoadWhenReady && alexCommandAcknowledged);

            end
            else if (curState == waitCore) begin
                readCounter <= '0;
                writeCounter <= '0;

                if(alexCommandAcknowledged && alexMemEnable == 2'b01 && ~alexFinishedMemAction)
                    outstandingMemRequests <= outstandingMemRequests + 1;
                else if(~(alexCommandAcknowledged && alexMemEnable == 2'b01) && alexFinishedMemAction)
                    outstandingMemRequests <= outstandingMemRequests - 1;
                    
                processingAlexCommand <= processingAlexCommand && ~alexCommandAcknowledged;
            end

            pipeline_modulo <= curState != readVGA && curState != waitVGA && rowColIndexReg[10:2] == 'd0 && ~vgaLoadWhenReady && drawY < 'd480 && drawX < 'd640;

            if(curState != readVGA && curState != waitVGA && rowColIndexReg[10:2] == 0 && ~vgaLoadWhenReady && drawY < 'd480 && drawX < 'd640) begin
                vgaLoadWhenReady <= 1; //On the 2048th iteration of the VGA, signal that it is ready to fetch new pixels from DDR3
                rowColPlusFrameBuf <= rowColIndexReg + addFrameBuffer + 'd2048; //save the address at which to get new pixels from (plus 2048)
            end
            else if (pipeline_modulo) begin
                if (rowColPlusFrameBuf >= 'd614400)
                    frozenRowColIndex <= rowColPlusFrameBuf - 'd614400;
                else
                    frozenRowColIndex <= rowColPlusFrameBuf;
                
            end
            else if (curState == readVGA) begin
                vgaLoadWhenReady <= 0; //reset the vgaLoadWhenReady whenever the reading from the DDR3 actually begins
            end
            oldDrawYExceed <= drawY < 480;

            if(!(drawY < 480) && oldDrawYExceed)
                frameBufIndex <= ~frameBufIndex;

        end
        pixel <= pixelsOut[{rowColIndexReg[1:0], 5'b00000} +: 32]; //use a register to hold the data of a pixel
    end
    
    always_comb begin
        red = pixel[31:24];
        green = pixel[23:16];
        blue = pixel[15:8];

        vgaAddress = {6'b000000, (frozenRowColIndex[19:2] + readCounter), 3'b000}; //increment the row-column index by the read counter

        alexAddress = (curState == sendCore || curState == waitCore) ? cacheAddress : vgaAddress;
        alexWriteData = cacheDataWrite;
        alexWriteBytes = cacheWriteBytes;
        
        case(curState)
            sendCore: alexNewCommand = cacheEnableGlobal;
            waitCore: alexNewCommand = cacheEnableGlobal && processingAlexCommand;
            readVGA: alexNewCommand = ~readCounter[9];
            waitVGA: alexNewCommand = 1'b0;
            default: alexNewCommand = 1'b0;
        endcase

        case(curState)
            sendCore: alexMemEnable = (cacheEnableGlobal) ? ((cacheEnableGlobalWrite) ? 2'b10 : 2'b01) : 2'b00;
            waitCore: alexMemEnable = (processingAlexCommand) ? ((cacheEnableGlobal) ? ((cacheEnableGlobalWrite) ? 2'b10 : 2'b01) : 2'b00) : 2'b00;
            readVGA: alexMemEnable = 2'b01;
            waitVGA: alexMemEnable = 2'b00;
            default: alexMemEnable = 2'b00;
        endcase
    end

    genvar i;
    generate
        for(i = 0; i<4; i+=1) begin
            vgaFrameBuffer u_blk_mem_gen_0 (
                .clka   (clk),       // Clock for port A
                .ena    (alexFinishedMemAction && (curState == readVGA || curState == waitVGA)), //whenever a read has been completed for a pixel
                .wea    (1'b1),
                .addra  ({~rowColIndexReg[11], writeCounter[8:0]}), // Address for port A
                .dina   (alexReadData[i*32 +: 32]),   
            
                .clkb   (clk),       // Clock for port B
                .enb    (1'b1),      // Enable for port B
                .addrb  (rowColIndexReg[11:2]), // Simply read the current pixel address
                .doutb  (pixelsOut[i*32 +: 32])   // Data output for port B
            );

        
        
        end
    endgenerate
    assign cacheFinishedRead = alexFinishedMemAction && (curState == sendCore || curState == waitCore);
    assign cacheFinishedCommand = (curState == sendCore || curState == waitCore) && alexCommandAcknowledged;

endmodule


//module memoryController(
//    input logic clk,
//    input logic reset,

//    //from the cache
//    input logic [127:0] cacheDataWrite,
//    input logic [26:0] cacheAddress,
//    output logic [127:0] cacheDataRead,
//    input logic cacheEnableGlobal,
//    input logic cacheEnableGlobalWrite,
//    input logic [15:0] cacheWriteBytes,
//    output logic cacheFinishedRead,
//    output logic cacheFinishedCommand,

//    //from the vga controller
//    input logic [9:0] drawX,
//    input logic [9:0] drawY,
//    output logic frame,
//    // input logic chooseBuffer,

//    //obvious
//    output logic [7:0] red,
//    output logic [7:0] green,
//    output logic [7:0] blue,

//    //talks to the ddr3
//    output logic [26:0] alexAddress,
//    input logic [127:0] alexReadData,
//    output logic [127:0] alexWriteData,
//    output logic [1:0] alexMemEnable,
//    output logic [15:0] alexWriteBytes,
//    input logic alexFinishedMemAction,
//    input logic alexCommandAcknowledged,
//    output logic alexNewCommand,
//    output logic onCore
//);
///*
//    ALL OF THE SAVE VALUES MUST BE SAVED IN 100MHZ, NOT 200MHZ!!!!

//*/
//    logic processingAlexCommand;
//    assign cacheDataRead = alexReadData;

//    logic [9:0] writeCounter;
//    logic [9:0] readCounter;
//    logic [19:0] rowColIndexWire, rowColIndexReg, frozenRowColIndex, addFrameBuffer, rowColPlusFrameBuf;    
//    logic [127:0] pixelsOut;
//    logic [31:0] pixel;    
//    logic [26:0] vgaAddress;

//    logic [7:0] outstandingMemRequests;
//    logic vgaLoadWhenReady, frameBufIndex;
//    logic holdingCommandSignalHigh, oldAlexCommandAcknowledged;
//    logic pipeline_modulo, oldDrawYExceed;
//    assign rowColIndexWire = drawX + drawY * 640;
//    assign addFrameBuffer = {20{frameBufIndex}} & 20'd307200;
//    assign frame = frameBufIndex;
//    typedef enum {
//        readVGA,
//        waitVGA,
        
//        sendCore,
//        waitCore
//    } memControllerState; //These are the different values that the state of the controller can take on

//    memControllerState curState;
    
    

    
    
//    always_ff @(posedge clk) begin
//        if(reset) begin
//            rowColIndexReg <= 0;
//            curState <= sendCore;
//            readCounter <= 0;
//            writeCounter <= 0;
//            frozenRowColIndex <= 0;
//            vgaLoadWhenReady <= 0;
//            outstandingMemRequests <= '0;
//            frameBufIndex <= '0;
//            pipeline_modulo <= '0;
//            oldDrawYExceed <= '0;
//            processingAlexCommand <= '0;
//        end
//        else begin
//            rowColIndexReg <= rowColIndexWire;
//            case(curState)
//                readVGA: curState <= (readCounter == 10'b0111111111 && alexCommandAcknowledged) ? waitVGA : readVGA;
//                waitVGA: curState <= (writeCounter == 10'b1000000000) ? sendCore : waitVGA;
//                sendCore: curState <= (vgaLoadWhenReady) ? waitCore : sendCore;
//                waitCore: curState <= (outstandingMemRequests == '0 && ~alexNewCommand) ? readVGA : waitCore;            
//            endcase            
//            if(curState == readVGA) begin
//                if(alexCommandAcknowledged) begin
//                    readCounter <= readCounter + 1; //increment the readCounter each time a new command is acknowledged/received
//                end
                
//                if(alexFinishedMemAction) begin
//                    writeCounter <= writeCounter + 1; //increment the writeCounter every time a read has been finished
//                end

//                outstandingMemRequests <= '0;
//            end
//            else if (curState == waitVGA) begin
//                if(alexFinishedMemAction) begin
//                    writeCounter <= writeCounter + 1; //increment the writeCounter every time a read has been finished
//                end

//                outstandingMemRequests <= '0;
//            end
//            else if (curState == sendCore) begin //when the state is sending the commands from the cores
//                if(alexCommandAcknowledged && alexMemEnable == 2'b01 && ~alexFinishedMemAction)
//                    outstandingMemRequests <= outstandingMemRequests + 1;
//                else if(~(alexCommandAcknowledged && alexMemEnable == 2'b01) && alexFinishedMemAction)
//                    outstandingMemRequests <= outstandingMemRequests - 1;

//                readCounter <= '0;
//                writeCounter <= '0;

//            end
//            else if (curState == waitCore) begin
//                readCounter <= '0;
//                writeCounter <= '0;

//                if(alexCommandAcknowledged && alexMemEnable == 2'b01 && ~alexFinishedMemAction)
//                    outstandingMemRequests <= outstandingMemRequests + 1;
//                else if(~(alexCommandAcknowledged && alexMemEnable == 2'b01) && alexFinishedMemAction)
//                    outstandingMemRequests <= outstandingMemRequests - 1;
                    
//            end

//            pipeline_modulo <= curState != readVGA && curState != waitVGA && rowColIndexReg[10:2] == 'd0 && ~vgaLoadWhenReady && drawY < 'd480 && drawX < 'd640;

//            if(curState != readVGA && curState != waitVGA && rowColIndexReg[10:2] == 0 && ~vgaLoadWhenReady && drawY < 'd480 && drawX < 'd640) begin
//                vgaLoadWhenReady <= 1; //On the 2048th iteration of the VGA, signal that it is ready to fetch new pixels from DDR3
//                rowColPlusFrameBuf <= rowColIndexReg + addFrameBuffer + 'd2048; //save the address at which to get new pixels from (plus 2048)
//            end
//            else if (pipeline_modulo) begin
//                if (rowColPlusFrameBuf >= 'd614400)
//                    frozenRowColIndex <= rowColPlusFrameBuf - 'd614400;
//                else
//                    frozenRowColIndex <= rowColPlusFrameBuf;
                
//            end
//            else if (curState == readVGA) begin
//                vgaLoadWhenReady <= 0; //reset the vgaLoadWhenReady whenever the reading from the DDR3 actually begins
//            end
//            oldDrawYExceed <= drawY < 480;

//            if(!(drawY < 480) && oldDrawYExceed)
//                frameBufIndex <= ~frameBufIndex;

//        end
//        pixel <= pixelsOut[{rowColIndexReg[1:0], 5'b00000} +: 32]; //use a register to hold the data of a pixel
//    end
    
//    always_comb begin
//        red = pixel[31:24];
//        green = pixel[23:16];
//        blue = pixel[15:8];

//        vgaAddress = {6'b000000, (frozenRowColIndex[19:2] + readCounter), 3'b000}; //increment the row-column index by the read counter
//    end
    
//    always_ff @(posedge clk) begin
//        if(reset) begin
//            alexMemEnable <= '0;
//            alexNewCommand <= '0;
//            alexAddress <= '0;
//            alexWriteBytes <= '0;
//            alexWriteData <= '0;
//        end
//        else begin

//            case(curState)
//                sendCore: alexNewCommand <= (alexNewCommand && ~alexCommandAcknowledged) || 
//                    (alexNewCommand && cacheEnableGlobal && ~vgaLoadWhenReady) || 
//                    (cacheEnableGlobal && ~vgaLoadWhenReady && ~alexCommandAcknowledged);
//                waitCore: alexNewCommand <= ~alexCommandAcknowledged && alexNewCommand;
//                readVGA: alexNewCommand <= ~(readCounter == 10'b0111111111 && alexCommandAcknowledged);
//                waitVGA: alexNewCommand <= 1'b0;
//                default: alexNewCommand <= 1'b0;
//            endcase
            
//            if(alexCommandAcknowledged || ~alexNewCommand) begin
//                alexAddress <= (curState == sendCore || curState == waitCore) ? cacheAddress : vgaAddress;
//                alexWriteData <= cacheDataWrite;
//                alexWriteBytes <= cacheWriteBytes;
                
//                case(curState)
//                    sendCore: alexMemEnable <= (cacheEnableGlobalWrite) ? 2'b10 : 2'b01;
//                    waitCore: alexMemEnable <= 2'b01;
//                    readVGA: alexMemEnable <= 2'b01;
//                    waitVGA: alexMemEnable <= 2'b00;
//                    default: alexMemEnable <= 2'b00;
//                endcase
//            end
//        end
//    end
//    genvar i;
//    generate
//        for(i = 0; i<4; i+=1) begin
//            vgaFrameBuffer u_blk_mem_gen_0 (
//                .clka   (clk),       // Clock for port A
//                .ena    (alexFinishedMemAction && (curState == readVGA || curState == waitVGA)), //whenever a read has been completed for a pixel
//                .wea    (1'b1),
//                .addra  ({~rowColIndexReg[11], writeCounter[8:0]}), // Address for port A
//                .dina   (alexReadData[i*32 +: 32]),   
            
//                .clkb   (clk),       // Clock for port B
//                .enb    (1'b1),      // Enable for port B
//                .addrb  (rowColIndexReg[11:2]), // Simply read the current pixel address
//                .doutb  (pixelsOut[i*32 +: 32])   // Data output for port B
//            );

        
        
//        end
//    endgenerate
//    assign cacheFinishedRead = alexFinishedMemAction && (curState == sendCore || curState == waitCore);
//    assign cacheFinishedCommand = ~vgaLoadWhenReady && cacheEnableGlobal && ~(alexNewCommand ^ alexCommandAcknowledged) && curState == sendCore;
//    assign onCore = (curState == sendCore || curState == waitCore);
//endmodule


