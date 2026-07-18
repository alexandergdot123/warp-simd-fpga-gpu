module cdcFifo(
    input logic clk_slow,
    input logic clk_fast,
    input logic rst,
   
    input logic [127:0] cacheDataWrite,
    input logic [26:0] cacheAddress,
    output logic [127:0] cacheDataRead,
    input logic cacheEnableGlobal,
    input logic cacheEnableGlobalWrite,
    input logic [15:0] cacheWriteBytes,
    output logic cacheFinishedRead,
    output logic memControllerReady,
    
    output logic [127:0] ddr3DataWrite,
    output logic [26:0] ddr3Address,
    input logic [127:0] ddr3DataRead,
    output logic ddr3EnableGlobal,
    output logic ddr3EnableGlobalWrite,
    output logic [15:0] ddr3WriteBytes,
    input logic ddr3FinishedRead,
    input logic ddr3FinishedCommand,
    input logic clk_lck,
    output logic [15:0] led
);
    logic [171:0] holdingValuesOut, values_in;
    logic cache_to_ddr3_empty, cache_to_ddr3_full, ddr3_to_cache_empty;
    assign memControllerReady = ~cache_to_ddr3_full;
    assign values_in[171] = cacheEnableGlobalWrite;
    assign values_in[170:144] = cacheAddress;
    assign values_in[143:128] = ~cacheWriteBytes;
    assign values_in[127:0] = cacheDataWrite;
    logic a, b;
    fifo_generator_0 cache_to_ddr3 (
        .full(cache_to_ddr3_full),
        .din(values_in), //172 + 8
        .wr_en(cacheEnableGlobal && ~a),
        .rst(rst),
        .empty(cache_to_ddr3_empty),
        .dout(holdingValuesOut),
        .rd_en(ddr3FinishedCommand && ~cache_to_ddr3_empty && ~b),
        .wr_rst_busy(a),
        .rd_rst_busy(b),
        .wr_clk(clk_slow),
        .rd_clk(clk_fast)
    );
    logic [15:0] counterA, counterB;
    // Read-side violation: rd_en asserted while empty or mid read-reset (all clk_fast)
    always_ff @(posedge clk_slow) begin
        if (rst) begin
            counterA <= '0;
        end
        else if (cacheEnableGlobal && cacheAddress[26:3] % 'd160 == '0 && cacheWriteBytes[3:0] == 4'b1111 && cacheDataWrite[31:8] != 24'h0055AA)
            counterA <= counterA + 1;
    end
    
    always_ff @(posedge clk_slow) begin
        if (rst) begin
            counterB <= '0;
        end
        else if (ddr3FinishedCommand && ~cache_to_ddr3_empty && ~b && ~ddr3EnableGlobalWrite) begin
            counterB <= counterB + 1;

            
        end

    end
    
    assign led = counterA;



    assign ddr3EnableGlobal = ~cache_to_ddr3_empty && ~b;
    assign ddr3DataWrite = holdingValuesOut[127:0];
    assign ddr3WriteBytes = holdingValuesOut[143:128];
    assign ddr3Address = holdingValuesOut[170:144];
    assign ddr3EnableGlobalWrite = holdingValuesOut[171];
    fifo_generator_1 ddr3_to_cache (
        .full(),
        .din(ddr3DataRead), 
        .wr_en(ddr3FinishedRead),
        .rst(rst),
        .empty(ddr3_to_cache_empty),
        .dout(cacheDataRead),
        .rd_en(~ddr3_to_cache_empty),
        
        .wr_clk(clk_fast),
        .rd_clk(clk_slow)
    );
    assign cacheFinishedRead = ~ddr3_to_cache_empty;

endmodule
