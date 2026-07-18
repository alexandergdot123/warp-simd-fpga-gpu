//`timescale 1ns/1ps
//module tb_fullSystemTop();

//    parameter NUM_CORES = 32;
//    parameter sharedMemSize = 65536;

//    // Clocks and reset
//    logic clk100;
//    logic clk200;
//    logic rst;

//    // Frontend instruction interface
//    logic [31:0] new_inst;
//    logic        new_inst_valid;
//    logic        fetch_queue_full;

//    // VGA
//    logic [9:0] drawX;
//    logic [9:0] drawY;
//    logic [7:0] red;
//    logic [7:0] green;
//    logic [7:0] blue;

//    // DDR3 physical I/O (driven by this TB to mimic DDR3)
//    logic [26:0] ram_address;
//    logic [2:0]  ram_cmd;
//    logic        ram_en;
//    logic        ram_rdy;
//    logic        ram_rd_valid;
//    logic        ram_rd_data_end;
//    logic [63:0] ram_rd_data;
//    logic [63:0] ram_wdf_data;
//    logic        ram_wdf_wren;
//    logic        ram_wdf_end;
//    logic [7:0]  ram_wdf_mask;
//    logic        ram_wdf_rdy;

//    // Instantiate DUT
//    fullSystemTop #(
//        .NUM_CORES(NUM_CORES),
//        .sharedMemSize(sharedMemSize)
//    ) dut (
//        .clk100(clk100),
//        .clk200(clk200),
//        .rst(rst),

//        // frontend
//        .new_inst(new_inst),
//        .new_inst_valid(new_inst_valid),
//        .fetch_queue_full(fetch_queue_full),

//        // vga
//        .drawX(drawX),
//        .drawY(drawY),
//        .red(red),
//        .green(green),
//        .blue(blue),

//        // ddr3 phys
//        .ram_address(ram_address),
//        .ram_cmd(ram_cmd),
//        .ram_en(ram_en),
//        .ram_rdy(ram_rdy),
//        .ram_rd_valid(ram_rd_valid),
//        .ram_rd_data_end(ram_rd_data_end),
//        .ram_rd_data(ram_rd_data),
//        .ram_wdf_data(ram_wdf_data),
//        .ram_wdf_wren(ram_wdf_wren),
//        .ram_wdf_end(ram_wdf_end),
//        .ram_wdf_mask(ram_wdf_mask),
//        .ram_wdf_rdy(ram_wdf_rdy)
//    );

//    logic         decode_pipe_divide;
//    logic         decode_pipe_load;
//    logic         decode_pipe_store;
//    logic         decode_pipe_mul;
//    logic         decode_pipe_alu;
//    logic [2:0]   decode_pipe_aluop;
//    logic [2:0]   ctx;
//    logic [31:0]  decode_pipe_imm, sr1_21, alu_out_21;
////    logic [3:0]   src1_id;
////    logic [3:0]   src2_id;
////    logic [3:0]   decode_pipe_dr;
////    logic [2:0]   decode_pipe_shift_amt;
////    logic [5:0]   instructions_to_skip;
////    logic [2:0]   decode_pipe_nzp;
////    logic         decode_pipe_shared;
////    logic [3:0]   decode_pipe_byte_enable;
//    logic cluster_decode_pipe_store;
//    logic [6:0] dr_sel;
//    assign cluster_decode_pipe_store = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.decode_pipe_store;
//    assign decode_pipe_divide          = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.core_array[21].core_inst.decode_pipe_divide;
//    assign decode_pipe_load            = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.core_array[21].core_inst.decode_pipe_load;
//    assign decode_pipe_store           = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.core_array[21].core_inst.decode_pipe_store;
//    assign decode_pipe_mul             = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.core_array[21].core_inst.decode_pipe_mul;
//    assign decode_pipe_alu             = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.core_array[21].core_inst.decode_pipe_alu;
//    assign decode_pipe_aluop           = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.core_array[21].core_inst.decode_pipe_aluop;
//    assign ctx                         = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.core_array[21].core_inst.ctx;
//    assign decode_pipe_imm             = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.core_array[21].core_inst.decode_pipe_imm;
//    assign sr1_21             = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.core_array[21].core_inst.sr1;
//    assign alu_out_21             = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.core_array[21].core_inst.alu_out;
//    assign dr_sel = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.core_array[21].core_inst.dr_sel;

////    assign src1_id                     = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.core_array[21].core_inst.src1_id;
////    assign src2_id                     = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.core_array[21].core_inst.src2_id;
////    assign decode_pipe_dr              = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.core_array[21].core_inst.decode_pipe_dr;
////    assign decode_pipe_shift_amt       = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.core_array[21].core_inst.decode_pipe_shift_amt;
////    assign instructions_to_skip        = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.core_array[21].core_inst.instructions_to_skip;
////    assign decode_pipe_nzp             = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.core_array[21].core_inst.decode_pipe_nzp;
////    assign decode_pipe_shared          = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.core_array[21].core_inst.decode_pipe_shared;
////    assign decode_pipe_byte_enable     = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.core_array[21].core_inst.decode_pipe_byte_enable;
////    logic [9:0] head, tail;
////    assign head = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.head;
////    assign tail = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.tail;
////    logic on_head, fetchQueueFull;
////    assign on_head = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.on_head;
////    assign fetchQueueFull = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.fetch_queue_full;
////    logic [3:0] opcode;
////    assign opcode = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.opcode;
////    logic load, store, mul, div, alu;
////    assign load = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.load;
////    assign store = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.store;
////    assign mul = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.mul;
////    assign div = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.divide;
////    assign alu = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.alu;
//    logic [9:0] writeCounter;
//    logic [9:0] readCounter;
//    logic [19:0] rowColIndexWire, rowColIndexReg, frozenRowColIndex, addFrameBuffer, rowColPlusFrameBuf;    
//    logic [127:0] pixelsOut;
//    logic [31:0] pixel;    
//    logic [26:0] vgaAddress;

//    logic [5:0] outstandingMemRequests;
//    logic vgaLoadWhenReady, frameBufIndex;
//    logic holdingLoadResultHigh;
//    logic holdingCommandSignalHigh, oldAlexCommandAcknowledged;
//    logic pipeline_modulo, oldDrawYExceed;
//    logic [1:0] memControllerState;
//    assign memControllerState = dut.memoryController_inst.curStateDebug;
//    assign writeCounter              = dut.memoryController_inst.writeCounter;
//assign readCounter               = dut.memoryController_inst.readCounter;
//assign rowColIndexWire           = dut.memoryController_inst.rowColIndexWire;
//assign rowColIndexReg            = dut.memoryController_inst.rowColIndexReg;
//assign frozenRowColIndex         = dut.memoryController_inst.frozenRowColIndex;
//assign addFrameBuffer            = dut.memoryController_inst.addFrameBuffer;
//assign rowColPlusFrameBuf        = dut.memoryController_inst.rowColPlusFrameBuf;
//assign pixelsOut                 = dut.memoryController_inst.pixelsOut;
//assign pixel                     = dut.memoryController_inst.pixel;
//assign vgaAddress                = dut.memoryController_inst.vgaAddress;

//assign outstandingMemRequests    = dut.memoryController_inst.outstandingMemRequests;
//assign vgaLoadWhenReady          = dut.memoryController_inst.vgaLoadWhenReady;
//assign frameBufIndex             = dut.memoryController_inst.frameBufIndex;
//assign holdingLoadResultHigh     = dut.memoryController_inst.holdingLoadResultHigh;
//assign holdingCommandSignalHigh  = dut.memoryController_inst.holdingCommandSignalHigh;
//assign oldAlexCommandAcknowledged= dut.memoryController_inst.oldAlexCommandAcknowledged;
//assign pipeline_modulo           = dut.memoryController_inst.pipeline_modulo;
//assign oldDrawYExceed            = dut.memoryController_inst.oldDrawYExceed;

//    logic [2:0] ctx_in_progress;
////    logic        divide;
//    logic        load;
//    logic        store;
////    logic [31:0] div_busy;
////    logic [31:0] load_busy;
////    logic [31:0] store_busy;
//    logic        trash_inst;
//    logic [127:0] cacheDataWrite;
//    logic [26:0]  cacheAddress;
//    logic [127:0] cacheDataRead;
//    logic         cacheEnableGlobal;
//    logic         cacheEnableGlobalWrite;
//    logic [15:0]  cacheWriteBytes;
//    logic         cacheFinishedRead;
//    logic         cacheFinishedCommand;
//    logic ctx_swtch;
//assign cacheDataWrite         = dut.gpuMemoryTop_inst.cacheDataWrite;
//assign cacheAddress           = dut.gpuMemoryTop_inst.cacheAddress;
//assign cacheDataRead          = dut.gpuMemoryTop_inst.cacheDataRead;
//assign cacheEnableGlobal      = dut.gpuMemoryTop_inst.cacheEnableGlobal;
//assign cacheEnableGlobalWrite = dut.gpuMemoryTop_inst.cacheEnableGlobalWrite;
//assign cacheWriteBytes        = dut.gpuMemoryTop_inst.cacheWriteBytes;
//assign cacheFinishedRead      = dut.gpuMemoryTop_inst.cacheFinishedRead;
//assign cacheFinishedCommand   = dut.gpuMemoryTop_inst.cacheFinishedCommand;

//    logic [1:0] commandCoreStoreQuantity;
//    logic [31:0] finishedStore;
//    assign commandCoreStoreQuantity = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.storeUnit.commandCoreStoreQuantity;
//    assign finishedStore = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.storeUnit.finishedStore;
////    // --- Assignments from DUT ---
//    assign ctx_in_progress    = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.ctx_in_progress;
////    assign divide             = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.divide;
//    assign load               = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.load;
//    assign store              = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.store;
////    assign div_busy           = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.div_busy;
////    assign load_busy          = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.load_busy;
////    assign store_busy         = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.store_busy;

////    logic ctx_in_progress;
//    assign trash_inst = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.trash_inst;
//    assign ctx_swtch = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.skip_ctx;
////    assign ctx_in_progress = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.ctx_in_progress;
////    logic [31:0] store_busy, load_busy, div_busy;
////    logic [7:0][9:0] cur_ctx_pc;
////    assign store_busy= dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.store_busy;
////    assign load_busy= dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.load_busy;
////    assign div_busy= dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.div_busy;
////    assign cur_ctx_pc= dut.gpuMemoryTop_inst.gpuClusterSystem_inst.cluster.ctx_pc;
////    logic [31:0][31:0] store_addr;
////    logic [31:0][31:0] store_value;
//    logic [31:0][3:0]  store_we;
//    logic [31:0]       store_enable;
//    logic [31:0]       store_finished;

////    logic [31:0][31:0] load_addr;
//    logic [31:0]       should_load;
//    logic [31:0]       load_finished;
////    logic [31:0][31:0] load_value;
////    assign store_addr     = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.store_addr;
////    assign store_value    = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.store_value;
//    assign store_we       = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.store_we;
//    assign store_enable   = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.store_enable;
//    assign store_finished = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.store_finished;
    
////    assign load_addr      = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.load_addr;
//    assign should_load    = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.should_load;
//    assign load_finished  = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.load_finished;
////    assign load_value     = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.load_value;
//    logic loadEnabling;
//    assign loadEnabling = dut.gpuMemoryTop_inst.memCrossDomain_inst.enablingLoads;
//    logic ddr3StartLoad;
//    assign ddr3StartLoad = dut.gpuMemoryTop_inst.ddr3StartLoad;
//    logic ddr3ReadyForLoad;
//    logic doLoad;
//    logic [31:0] visitedCore, enableLoad;
//        assign visitedCore = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.loadUnit.visitedCore;
//    assign enableLoad = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.loadUnit.enableLoad;

//    assign ddr3ReadyForLoad = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.loadUnit.ddr3ReadyForLoad;
//    assign doLoad = dut.gpuMemoryTop_inst.gpuClusterSystem_inst.loadUnit.doLoad;
//    // -----------------------------------------------------------
//    // Clocks
//    // -----------------------------------------------------------
//    initial begin
//        clk100 = 0;
//        forever #10 clk100 = ~clk100; // 100 MHz -> 10 ns period ; toggles every 5ns
//    end

//    initial begin
//        clk200 = 0;
//        forever #5 clk200 = ~clk200; // 200 MHz -> 5 ns period ; toggles every 2.5ns
//    end

//    // -----------------------------------------------------------
//    // Reset and initial conditions
//    // -----------------------------------------------------------
//    initial begin
//        rst = 1;
//        new_inst = 32'h0000_0000;
//        new_inst_valid = 0;
//        drawX = 0;
//        drawY = 0;
//        ram_rd_valid = 0;
//        ram_rd_data_end = 0;
//        ram_rd_data = 64'h0;
//        ram_rdy = 1;        // DDR controller ready by default
//        ram_wdf_rdy = 1;    // Write data FIFO ready by default
//        ram_wdf_mask = 8'hFF;

//        #200; // 200 ns reset time to let everything initialize
//        rst = 0;
//        #10;
//    end

//    // -----------------------------------------------------------
//    // Instruction feed: a new instruction every other clk100 rising edge
//    // You said you'll put the machine code; edit `inst_mem` below.
//    // -----------------------------------------------------------
    
   
//    initial begin
//        #1000;
//        new_inst = 32'h11F800AA;//changed second char from E to F to write to unwriteable reg
//        new_inst_valid = 1;
//        #20;
//        new_inst_valid = 0;
//        #20;
//        new_inst = 32'h1117C000;
//        new_inst_valid = 1;
//        #20;
//        new_inst_valid = 0;
//        #20;
//        new_inst = 32'h32180003;//changed second char from E to F to write to unwriteable reg
//        new_inst_valid = 1;
//        #20;
//        new_inst_valid = 0;
//        #20;
//        new_inst = 32'h53F08000;
//        new_inst_valid = 1;
//        #20;
//        new_inst_valid = 0;
//        #20;
//                new_inst = 32'h54F80000;//changed second char from E to F to write to unwriteable reg
//        new_inst_valid = 1;
//        #20;
//        new_inst_valid = 0;
//        #20;
//        new_inst = 32'h05350000;
//        new_inst_valid = 1;
//        #20;
//        new_inst_valid = 0;
//        #20;
//                new_inst = 32'h26F00000;//changed second char from E to F to write to unwriteable reg
//        new_inst_valid = 1;
//        #20;
//        new_inst_valid = 0;
//        #20;
//        new_inst = 32'h07214000;
//        new_inst_valid = 1;
//        #20;
//        new_inst_valid = 0;
//        #20;
//                        new_inst = 32'h08718000;//changed second char from E to F to write to unwriteable reg
//        new_inst_valid = 1;
//        #20;
//        new_inst_valid = 0;
//        #20;
//        new_inst = 32'hAF800000;
//        new_inst_valid = 1;
//        #20;
//        new_inst_valid = 0;
//        #20;
//                new_inst = 32'h09F80001;//changed second char from E to F to write to unwriteable reg
//        new_inst_valid = 1;
//        #20;
//        new_inst_valid = 0;
//        #20;
//        new_inst = 32'h69608100;
//        new_inst_valid = 1;
//        #20;
//        new_inst_valid = 0;
//        #20;
//                new_inst = 32'h099C0100;//changed second char from E to F to write to unwriteable reg
//        new_inst_valid = 1;
//        #20;
//        new_inst_valid = 0;
//        #20;
//        new_inst = 32'h8A980000;
//        new_inst_valid = 1;
//        #20;
//        new_inst_valid = 0;
//        #20;
        
        
        
        
        
        

////        new_inst = 32'hDEADBEEF;
////        new_inst_valid = 1;
////        #20;
////        new_inst_valid = 0;
////        #20;
////        new_inst = 32'h01234567;
////        new_inst_valid = 1;
////        #20;
////        new_inst_valid = 0;
////        #20;
////        new_inst = 32'hDEADBEEF;
////        new_inst_valid = 1;
////        #20;
////        new_inst_valid = 0;
////        #20;
////        new_inst = 32'h01234567;
////        new_inst_valid = 1;
////        #20;
////        new_inst_valid = 0;
////        #20;
////        new_inst = 32'hDEADBEEF;
////        new_inst_valid = 1;
////        #20;
////        new_inst_valid = 0;
////        #20;
////        new_inst = 32'h01234567;
////        new_inst_valid = 1;
////        #20;
////        new_inst_valid = 0;
////        #20;
//    end

//    // -----------------------------------------------------------
//    // VGA drawX, drawY generator
//    // Each (x,y) held for 40 ns
//    // 40 ns may not align to clock edges exactly; update driven in a time domain process
//    // -----------------------------------------------------------
//    initial begin
//        // We will update drawX/drawY every 40 ns
//        // Start at 0,0 after reset release
//        wait (!rst);
//        #10; // small offset
//        drawX = 0;
//        drawY = 0;
//        forever begin
//            #80;
//            if (drawX == 10'd799) begin
//                drawX = 0;
//                if (drawY == 10'd599) begin
//                    drawY = 0;
//                end else begin
//                    drawY = drawY + 1;
//                end
//            end else begin
//                drawX = drawX + 1;
//            end
//        end
//    end

//// -----------------------------------------------------------
//// Simple behavioral DDR3 model for reads/writes from ram_address/ram_cmd/ram_en
//// with a maximum of 10 outstanding reads (ram_rdy goes low when full)
//// -----------------------------------------------------------
//typedef struct packed {
//    logic [26:0] addr;
//    time         issue_time;
//    int          id;
//} rd_req_t;

//rd_req_t rd_q[$]; // dynamic queue

//integer req_id = 0;

//// DDR3 ready signals
//logic ram_rdy_internal;
//assign ram_rdy = ram_rdy_internal;  // drive DUT from this
//assign ram_wdf_rdy = 1'b1;          // writes always ready

//// ===========================================================
//// Monitor for command issuance
//// ===========================================================
//logic ram_en_d;
//always_ff @(posedge clk200) begin
//    ram_en_d <= ram_en;

//    // Update readiness: if too many outstanding, block new reads
//    ram_rdy_internal <= (rd_q.size() < 10);

//    // detect new command when ram_en rises
//    if (!ram_en_d && ram_en) begin
//        if (ram_cmd == 3'b001) begin
//            if (ram_rdy_internal) begin
//                // queue the read
//                rd_req_t rq;
//                rq.addr = ram_address;
//                rq.issue_time = $time;
//                rq.id = req_id;
//                req_id = req_id + 1;
//                rd_q.push_back(rq);
//                $display("[%0t] TB: Read cmd queued addr=%0h id=%0d (total=%0d)", 
//                         $time, rq.addr, rq.id, rd_q.size());
//            end else begin
//                $display("[%0t] TB: Read cmd IGNORED (ram_rdy=0, too many outstanding=%0d)", 
//                         $time, rd_q.size());
//            end
//        end else if (ram_cmd == 3'b000) begin
//            // write command
//            $display("[%0t] TB: Write cmd addr=%0h", $time, ram_address);
//        end else begin
//            $display("[%0t] TB: Other cmd %b addr=%0h", $time, ram_cmd, ram_address);
//        end
//    end
//end

//// ===========================================================
//// Memory model
//// ===========================================================
//typedef struct packed {
//    logic [127:0] data;
//} mem_entry_t;
//mem_entry_t sim_mem [0:16383];

//initial begin
//    integer i;
//    for (i = 0; i < 16384; i = i + 1)
//        sim_mem[i].data = {32'hA5A5A5A5, 32'h5A5A5A5A, 32'hCAFEBABE, i[31:0]};
//end

//integer mem_idx;
//logic [127:0] out128;
//rd_req_t cur;
//integer latency_ns;

//// ===========================================================
//// Background read service
//// ===========================================================
//initial begin
//    ram_rd_valid = 0;
//    ram_rd_data_end = 0;
//    forever begin
//        if (rd_q.size() > 0) begin
//            cur = rd_q.pop_front();
//            latency_ns = $urandom_range(20, 200);
//            $display("[%0t] TB: Scheduling response id=%0d addr=%0h latency=%0d ns (remaining=%0d)", 
//                     $time, cur.id, cur.addr, latency_ns, rd_q.size());

//            // Wait for the latency
//            #(latency_ns);

//            // Perform the response in a SERIALIZED fashion
//            mem_idx = cur.addr[26:3];
//            if (mem_idx < 16384)
//                out128 = sim_mem[mem_idx].data;
//            else
//                out128 = {96'h0, cur.addr};

//            // Beat 1
//            @(posedge clk200);
//            ram_rd_data     = out128[127:64];
//            ram_rd_valid    = 1;
//            ram_rd_data_end = 0;

//            // Beat 2
//            @(posedge clk200);
//            ram_rd_data     = out128[63:0];
//            ram_rd_valid    = 1;
//            ram_rd_data_end = 1;

//            // Idle
//            @(posedge clk200);
//            ram_rd_valid    = 0;
//            ram_rd_data_end = 0;
//        end else begin
//            #10;
//        end
//    end
//end


//// ===========================================================
//// Write handler
//// ===========================================================
//logic write_pending;
//logic [26:0] last_write_addr;
//logic [127:0] write_assem;
//integer midx;
//initial begin
//    write_pending = 0;
//    last_write_addr = 0;
//    write_assem = 128'h0;
//    forever begin
//        @(posedge clk200);
//        if (ram_wdf_wren) begin
//            if (!write_pending) begin
//                write_assem[127:64] = ram_wdf_data;
//                write_pending = 1;
//                last_write_addr = ram_address[26:3];
//                $display("[%0t] TB: Captured WRITE BEAT1 addr=%0h data_high=%h", 
//                         $time, last_write_addr, ram_wdf_data);
//            end else begin
//                write_assem[63:0] = ram_wdf_data;
//                write_pending = 0;
//                midx = last_write_addr;
//                if (midx < 16384) begin
//                    sim_mem[midx].data = write_assem;
//                    $display("[%0t] TB: WRITE COMMIT addr=%0h data=%h", 
//                             $time, midx, write_assem);
//                end else begin
//                    $display("[%0t] TB: WRITE commit out-of-range idx=%0d", 
//                             $time, midx);
//                end
//            end
//        end
//    end
//end


//    // -----------------------------------------------------------
//    // VCD dump and run control
//    // -----------------------------------------------------------
//    initial begin
//        $dumpfile("tb_fullSystemTop.vcd");
//        $dumpvars(0, tb_fullSystemTop);
//        // run for a set time, e.g., 100 us
//        #300_000;
//        $display("Testbench finished at time %0t", $time);
//        $finish;
//    end

//endmodule

//// Wrapper that instantiates fullSystemTop with 32 cores and 65536 bytes.
//// All declared logic signals are marked with (* keep = "true" *).

//module fullSystemTop_inst_wrapper ();

//    // clocks / reset
//    (* keep = "true" *) logic clk100;
//    (* keep = "true" *) logic clk200;
//    (* keep = "true" *) logic rst;

//    // frontend instruction interface
//    (* keep = "true" *) logic [31:0] new_inst;
//    (* keep = "true" *) logic        new_inst_valid;
//    (* keep = "true" *) logic        fetch_queue_full;

//    // VGA signals
//    (* keep = "true" *) logic [9:0] drawX;
//    (* keep = "true" *) logic [9:0] drawY;
//    (* keep = "true" *) logic [7:0] red;
//    (* keep = "true" *) logic [7:0] green;
//    (* keep = "true" *) logic [7:0] blue;

//    // DDR3 physical I/O
//    (* keep = "true" *) logic [26:0] ram_address;
//    (* keep = "true" *) logic [2:0]  ram_cmd;
//    (* keep = "true" *) logic        ram_en;
//    (* keep = "true" *) logic        ram_rdy;
//    (* keep = "true" *) logic        ram_rd_valid;
//    (* keep = "true" *) logic        ram_rd_data_end;
//    (* keep = "true" *) logic [63:0] ram_rd_data;
//    (* keep = "true" *) logic [63:0] ram_wdf_data;
//    (* keep = "true" *) logic        ram_wdf_wren;
//    (* keep = "true" *) logic        ram_wdf_end;
//    (* keep = "true" *) logic [7:0]  ram_wdf_mask;
//    (* keep = "true" *) logic        ram_wdf_rdy;

//    // Instantiate the DUT
//    fullSystemTop #(
//        .NUM_CORES(32),
//        .sharedMemSize(65536)
//    ) fullSystemTop_inst (
//        .clk100(clk100),
//        .clk200(clk200),
//        .rst(rst),

//        // frontend
//        .new_inst(new_inst),
//        .new_inst_valid(new_inst_valid),
//        .fetch_queue_full(fetch_queue_full),

//        // vga
//        .drawX(drawX),
//        .drawY(drawY),
//        .red(red),
//        .green(green),
//        .blue(blue),

//        // ddr3 phys
//        .ram_address(ram_address),
//        .ram_cmd(ram_cmd),
//        .ram_en(ram_en),
//        .ram_rdy(ram_rdy),
//        .ram_rd_valid(ram_rd_valid),
//        .ram_rd_data_end(ram_rd_data_end),
//        .ram_rd_data(ram_rd_data),
//        .ram_wdf_data(ram_wdf_data),
//        .ram_wdf_wren(ram_wdf_wren),
//        .ram_wdf_end(ram_wdf_end),
//        .ram_wdf_mask(ram_wdf_mask),
//        .ram_wdf_rdy(ram_wdf_rdy)
//    );

//    // Optional: simple clock generators for simulation convenience (uncomment if wanted)
//    /*
//    initial begin
//        clk100 = 0; forever #5 clk100 = ~clk100; // 100 MHz
//    end
//    initial begin
//        clk200 = 0; forever #2.5 clk200 = ~clk200; // 200 MHz
//    end
//    initial begin
//        rst = 1; #200; rst = 0;
//    end
//    */

//endmodule
