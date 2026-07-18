//module ram_reader(
//    input  logic clk,
//    input  logic reset,               
    
//    output logic [26:0] ram_address,
//    output logic [2:0] ram_cmd,       
//    output logic ram_en,             
//    input  logic ram_rdy,
//    input  logic ram_rd_valid,
//    input  logic ram_rd_data_end,
//    input  logic [63:0] ram_rd_data,
//    output logic [63:0] ram_wdf_data,
//    output logic ram_wdf_wren,
//    output logic ram_wdf_end,
//    output logic [7:0] ram_wdf_mask,
//    input  logic ram_wdf_rdy,
    
//    input  logic [26:0] alexAddress,
//    input  logic [127:0] alexWriteData,
//    output logic [127:0] alexReadData,
//    output logic alexFinishedAction,
//    input  logic [1:0] alexMemEnable,
//    input  logic [15:0] alexWriteBytes,
//    output logic [3:0] alexMemReady,
//    input  logic alexNewCommand,
//    output logic alexFinishedCommand,
//    output logic processingAlexCommand
//);

//    logic [2:0] writeState;
//    logic [1:0] readState;
//    logic [6:0] counter;
//    assign checkWriteBytes = ram_wdf_mask;
//    assign ram_wdf_rdy_debug = ram_wdf_rdy;
//    logic [63:0] ram_rd_data_copy;
//    assign ram_rd_data_copy = ram_rd_data;
//    logic ram_rdy_old, ram_rd_valid_old, ram_rd_data_end_old;

//    // =========================================================
//    // DEBUG PROBE SIGNALS
//    // =========================================================

//    always_ff @(posedge clk) begin
//        ram_rdy_old <= ram_rdy;
//        ram_rd_valid_old <= ram_rd_valid;
//        ram_rd_data_end_old <= ram_rd_data_end;
    
//        if (reset) begin
//            ram_cmd <= 3'b000;
//            alexReadData <= 'h0;
//            alexFinishedAction <= 0;
//            writeState <= 3'b000;
//            ram_wdf_data <= 0;
//            counter <= 0;
//        end 
//        else begin
//            if(alexMemEnable == 2'b01 && ~alexFinishedAction) begin
//                counter <= counter + 1;
//            end
//            else begin
//                counter <= 0;
//            end
            
//            case(writeState)
//                3'b000: writeState <= (alexNewCommand && alexMemEnable == 2'b10 && ram_rdy) ? 3'b001: 3'b000;
//                3'b001: writeState <= (ram_rdy) ? 3'b010 : 3'b001;
//                3'b010: writeState <= (ram_wdf_rdy) ? 3'b011 : 3'b010;
//                3'b011: writeState <= (ram_wdf_rdy) ? 3'b100 : 3'b011;
//                3'b100: writeState <= 3'b000;
//            endcase       
//            case(readState)
//                2'b00: readState <= (alexNewCommand && alexMemEnable == 2'b01 && ram_rdy) ? 2'b01 : 2'b00;
//                2'b01: readState <= (ram_rdy && ram_rdy_old) ? 2'b10 : 2'b01;
//                2'b10: readState <= 2'b11; 
//                2'b11: readState <= 2'b00;
//            endcase

//            if(alexMemEnable == 2'b00) begin
//                alexFinishedCommand <= 0;
//                alexFinishedAction <= 0;
//                readState <= 2'b00;
//                writeState <= 3'b000;
//            end
//            else if (alexMemEnable == 2'b01) begin
//                if(ram_rdy && alexNewCommand && readState == 2'b00) begin
//                    ram_cmd <= 3'b001;
//                    ram_address <= {alexAddress[26:3], 3'b000};
//                    alexFinishedCommand <= 0;
//                end
//                else if (readState == 2'b01 && ram_rdy && ram_rdy_old) begin
//                    alexFinishedCommand <= 1;
//                end
//                else begin
//                    alexFinishedCommand <= 0;
//                end               
//            end
//            else if (alexMemEnable == 2'b10) begin
//                if(writeState == 3'b000 && alexNewCommand && ram_rdy) begin 
//                    ram_cmd <= 3'b000;
//                    ram_address <= {alexAddress[26:3], 3'b000};
//                    alexFinishedCommand <= 0;
//                end
//                else if (writeState == 3'b001) begin
//                    ram_wdf_data <= alexWriteData[127:64];
//                end
//                else if (writeState == 3'b010 && ram_wdf_rdy) begin
//                    ram_wdf_data <= alexWriteData[63:0];
//                    alexFinishedCommand <= 0;
//                end
//                else if (writeState == 3'b011) begin
//                    alexFinishedCommand <= 1;                
//                end
//                else if (writeState == 3'b100) begin
//                    alexFinishedCommand <= 0;        
//                end
//            end

//            if((ram_rd_valid_old && ram_rd_data_end && ~ram_rd_data_end_old && ~alexFinishedAction) || (&counter)) begin
//                alexReadData[63:0] <= ram_rd_data;
//                alexFinishedAction <= 1;
//            end
//            else if(ram_rd_valid) begin
//                alexReadData[127:64] <= ram_rd_data;     
//                alexFinishedAction <= 0;          
//            end
//            else begin
//                alexFinishedAction <= 0;
//            end
//        end
//    end
//    assign ram_wdf_mask = (writeState == 3'b011) ? alexWriteBytes[7:0] : alexWriteBytes[15:8];

//    assign ram_en = (readState == 2'b01 && ram_rdy && ram_rdy_old) || (writeState == 3'b001);
//    assign ram_wdf_end = writeState == 3'b011;
//    assign ram_wdf_wren = writeState == 3'b010 || writeState == 3'b011;
//    assign alexMemReady[0] = ram_rdy;
//    assign alexMemReady[1] = ram_wdf_wren;
//    assign alexMemReady[2] = ram_wdf_end;
//    assign alexMemReady[3] = ram_en;
//    assign processingAlexCommand = writeState != 3'b000 || readState != 2'b00;
//endmodule
// =============================================================================
// ram_reader.sv  --  native-UI interactor for the MIG 7-series DDR3 controller
//
// Target: xc7s50-csga324-1IL, MT41K64M16 (1Gb x16, DDR3L), tCK=3000ps, PHY:CTRL=2:1
//   ui_clk = 166.67 MHz, APP_DATA_WIDTH=64, APP_MASK_WIDTH=8, BL8 => 2 UI beats.
//
// Contract with the "alex" side:
//   * alexNewCommand is held HIGH while a command is presented, and all request
//     fields (alexAddress / alexWriteData / alexWriteBytes / alexMemEnable) stay
//     stable for as long as it is high. The block relies on this -- it drives the
//     MIG address/cmd/data straight from the live inputs, no internal latching.
//   * alexMemEnable[1] = write, alexMemEnable[0] = read (write wins if both set).
//   * alexFinishedCommand pulses HIGH for one cycle when the command is done
//     (write: both beats committed to the WDF + cmd accepted; read: data returned).
//     The cycle after the pulse, a still-high alexNewCommand is a NEW command.
//   * alexFinishedAction pulses HIGH for one cycle ONLY on the return of load data.
//   * alexWriteBytes is MIG-native mask polarity: 0 = byte written, 1 = masked.
//
// HIGH_HALF_FIRST preserves the existing convention (first DRAM beat <-> bits
// [127:64]). Set to 0 for natural ordering (first beat <-> [63:0]) if the HDMI
// scanout / other masters read this DRAM with little-endian byte order.
// =============================================================================
//module ram_reader #(
//  parameter int ADDR_WIDTH      = 27,
//  parameter bit HIGH_HALF_FIRST = 1'b1
//)(
//  input  logic                  clk,
//  input  logic                  reset,

//  // ---- MIG native user interface ----
//  output logic [ADDR_WIDTH-1:0] ram_address,
//  output logic [2:0]            ram_cmd,
//  output logic                  ram_en,
//  input  logic                  ram_rdy,
//  input  logic                  ram_rd_valid,
//  input  logic                  ram_rd_data_end,
//  input  logic [63:0]           ram_rd_data,
//  output logic [63:0]           ram_wdf_data,
//  output logic                  ram_wdf_wren,
//  output logic                  ram_wdf_end,
//  output logic [7:0]            ram_wdf_mask,
//  input  logic                  ram_wdf_rdy,

//  // ---- alex side ----
//  input  logic [ADDR_WIDTH-1:0] alexAddress,
//  input  logic [127:0]          alexWriteData,
//  output logic [127:0]          alexReadData,
//  output logic                  alexFinishedAction,   // -> alexFinishedMemAction
//  input  logic [1:0]            alexMemEnable,
//  input  logic [15:0]           alexWriteBytes,
//  input  logic                  alexNewCommand,
//  output logic                  alexFinishedCommand,  // -> alexCommandAcknowledged
//  output logic                  processingAlexCommand
//);

//  localparam logic [2:0] CMD_WRITE = 3'b000;
//  localparam logic [2:0] CMD_READ  = 3'b001;

//  wire is_write = alexNewCommand &&  alexMemEnable[1];
//  wire is_read  = alexNewCommand &&  alexMemEnable[0] && ~alexMemEnable[1];

//  // =========================================================================
//  // READ DATA PATH  (stateless; unlimited outstanding, in order)
//  // =========================================================================
//  logic [63:0] rd_hi;
//  always_ff @(posedge clk) begin
//    if (reset)                                  rd_hi <= 64'd0;
//    else if (ram_rd_valid && !ram_rd_data_end)  rd_hi <= ram_rd_data; // first beat
//  end

//  assign alexReadData       = HIGH_HALF_FIRST ? {rd_hi, ram_rd_data}
//                                              : {ram_rd_data, rd_hi};
//  assign alexFinishedAction = ram_rd_valid && ram_rd_data_end;        // 1 pulse / read

//  // =========================================================================
//  // COMMAND PATH
//  // =========================================================================
//  typedef enum logic [0:0] { IDLE, WRITE } cstate_t;
//  cstate_t              state;
//  logic [1:0]           wbeat;       // write beats committed: 0,1,2
//  logic                 wcmd_sent;   // write command accepted
//  logic                 wr_block;    // 1 => this store already issued; don't repeat
//  logic [ADDR_WIDTH-1:0] last_waddr; // address of the store we last issued

//  // a store may be launched only when it is a genuinely new request
//  wire issue_write = is_write && ~wr_block;

//  logic [63:0] wbeat_data;
//  logic [7:0]  wbeat_mask;
//  always_comb begin
//    if (wbeat == 2'd0) begin
//      wbeat_data = HIGH_HALF_FIRST ? alexWriteData[127:64] : alexWriteData[63:0];
//      wbeat_mask = HIGH_HALF_FIRST ? alexWriteBytes[15:8]  : alexWriteBytes[7:0];
//    end else begin
//      wbeat_data = HIGH_HALF_FIRST ? alexWriteData[63:0]   : alexWriteData[127:64];
//      wbeat_mask = HIGH_HALF_FIRST ? alexWriteBytes[7:0]   : alexWriteBytes[15:8];
//    end
//  end

//  always_comb begin
//    ram_address  = {alexAddress[ADDR_WIDTH-1:3], 3'b000};
//    ram_cmd      = (state == WRITE || alexMemEnable[1]) ? CMD_WRITE : CMD_READ;
//    ram_wdf_data = wbeat_data;
//    ram_wdf_mask = wbeat_mask;

//    ram_en       = 1'b0;
//    ram_wdf_wren = 1'b0;
//    ram_wdf_end  = 1'b0;

//    if (state == IDLE) begin
//      if (is_read) begin
//        ram_en = 1'b1;                       // pipelined read; accepted on ram_rdy
//      end else if (issue_write) begin
//        ram_en       = 1'b1;                 // command + beat0 together
//        ram_wdf_wren = (wbeat != 2'd2);
//        ram_wdf_end  = (wbeat == 2'd1);
//      end
//    end else begin // WRITE
//      ram_en       = ~wcmd_sent;
//      ram_wdf_wren = (wbeat != 2'd2);
//      ram_wdf_end  = (wbeat == 2'd1);
//    end
//  end

//  wire read_ack  = (state == IDLE) && is_read && ram_rdy;
//  wire write_ack = (state == WRITE)
//                && ((wbeat == 2'd2) || (wbeat == 2'd1 && ram_wdf_rdy))
//                && (wcmd_sent || ram_rdy);

//  assign alexFinishedCommand   = read_ack || write_ack;
//  assign processingAlexCommand = (state == WRITE);

//  always_ff @(posedge clk) begin
//    if (reset) begin
//      state      <= IDLE;
//      wbeat      <= 2'd0;
//      wcmd_sent  <= 1'b0;
//      wr_block   <= 1'b0;
//      last_waddr <= '0;
//    end else begin
//      // release the block as soon as the store request goes away or moves on
//      if (~is_write || alexAddress != last_waddr)
//        wr_block <= 1'b0;

//      case (state)
//        IDLE: begin
//          wbeat     <= 2'd0;
//          wcmd_sent <= 1'b0;
//          if (issue_write) begin
//            wcmd_sent  <= ram_rdy;                    // cmd accepted this cycle?
//            wbeat      <= ram_wdf_rdy ? 2'd1 : 2'd0;  // beat0 accepted this cycle?
//            last_waddr <= alexAddress;
//            state      <= WRITE;
//          end
//          // reads stay IDLE -- read_ack is the whole handshake
//        end
//        WRITE: begin
//          if (ram_rdy) wcmd_sent <= 1'b1;
//          if (ram_wdf_wren && ram_wdf_rdy && wbeat != 2'd2)
//            wbeat <= wbeat + 2'd1;
//          if (write_ack) begin
//            state     <= IDLE;
//            wbeat     <= 2'd0;
//            wcmd_sent <= 1'b0;
//            wr_block  <= 1'b1;   // one store issued; block repeats until it changes
//          end
//        end
//      endcase
//    end
//  end

//endmodule

//module ram_reader #(
//  parameter int ADDR_WIDTH      = 27,
//  parameter bit HIGH_HALF_FIRST = 1'b1
//)(
//  input  logic                  clk,
//  input  logic                  reset,

//  // ---- MIG native user interface ----
//  output logic [ADDR_WIDTH-1:0] ram_address,
//  output logic [2:0]            ram_cmd,
//  output logic                  ram_en,
//  input  logic                  ram_rdy,
//  input  logic                  ram_rd_valid,
//  input  logic                  ram_rd_data_end,
//  input  logic [63:0]           ram_rd_data,
//  output logic [63:0]           ram_wdf_data,
//  output logic                  ram_wdf_wren,
//  output logic                  ram_wdf_end,
//  output logic [7:0]            ram_wdf_mask,
//  input  logic                  ram_wdf_rdy,

//  // ---- alex side ----
//  input  logic [ADDR_WIDTH-1:0] alexAddress,
//  input  logic [127:0]          alexWriteData,
//  output logic [127:0]          alexReadData,
//  output logic                  alexFinishedAction,   // -> alexFinishedMemAction
//  input  logic [1:0]            alexMemEnable,
//  input  logic [15:0]           alexWriteBytes,
//  input  logic                  alexNewCommand,
//  output logic                  alexFinishedCommand,  // -> alexCommandAcknowledged
//  output logic                  processingAlexCommand
//);

//  localparam logic [2:0] CMD_WRITE = 3'b000;
//  localparam logic [2:0] CMD_READ  = 3'b001;

//  wire is_write = alexNewCommand &&  alexMemEnable[1];
//  wire is_read  = alexNewCommand &&  alexMemEnable[0] && ~alexMemEnable[1];

//  // =========================================================================
//  // READ DATA PATH  (stateless; unlimited outstanding, in order)
//  // =========================================================================
//  logic [63:0] rd_hi;
//  always_ff @(posedge clk) begin
//    if (reset)                                  rd_hi <= 64'd0;
//    else if (ram_rd_valid && !ram_rd_data_end)  rd_hi <= ram_rd_data; // first beat
//  end

//  assign alexReadData       = HIGH_HALF_FIRST ? {rd_hi, ram_rd_data}
//                                              : {ram_rd_data, rd_hi};
//  assign alexFinishedAction = ram_rd_valid && ram_rd_data_end;        // 1 pulse / read

//  // =========================================================================
//  // COMMAND PATH
//  //   IDLE  : reads issue here; a store issues command+beat0 atomically here
//  //   WR_B1 : push the second beat, then the store is done
//  // =========================================================================
//  typedef enum logic [0:0] { IDLE, WR_B1 } cstate_t;
//  cstate_t               state;
//  logic                  wr_block;    // 1 => this store already issued
//  logic [ADDR_WIDTH-1:0] last_waddr;

//  wire issue_write = is_write && ~wr_block;

//  // first beat in IDLE, second beat in WR_B1
//  logic [63:0] beat_data;
//  logic [7:0]  beat_mask;
//  always_comb begin
//    if (state == WR_B1) begin
//      beat_data = HIGH_HALF_FIRST ? alexWriteData[63:0]   : alexWriteData[127:64];
//      beat_mask = HIGH_HALF_FIRST ? alexWriteBytes[7:0]   : alexWriteBytes[15:8];
//    end else begin
//      beat_data = HIGH_HALF_FIRST ? alexWriteData[127:64] : alexWriteData[63:0];
//      beat_mask = HIGH_HALF_FIRST ? alexWriteBytes[15:8]  : alexWriteBytes[7:0];
//    end
//  end

//  always_comb begin
//    ram_address  = {alexAddress[ADDR_WIDTH-1:3], 3'b000};
//    ram_cmd      = (alexMemEnable[1] || state != IDLE) ? CMD_WRITE : CMD_READ;
//    ram_wdf_data = beat_data;
//    ram_wdf_mask = beat_mask;

//    ram_en       = 1'b0;
//    ram_wdf_wren = 1'b0;
//    ram_wdf_end  = 1'b0;

//    if (state == IDLE) begin
//      if (is_read) begin
//        ram_en = 1'b1;                       // pipelined read; accepted on ram_rdy
//      end else if (issue_write) begin
//        // command + beat0 accepted atomically: each gated on the OTHER's ready
//        ram_en       = ram_wdf_rdy;          // command only if WDF can take beat0
//        ram_wdf_wren = ram_rdy;              // beat0 only if command will be taken
//        ram_wdf_end  = 1'b0;
//      end
//    end else begin // WR_B1
//      ram_wdf_wren = 1'b1;                    // second beat
//      ram_wdf_end  = 1'b1;
//    end
//  end

//  wire read_ack  = (state == IDLE)  && is_read && ram_rdy;
//  wire write_ack = (state == WR_B1) && ram_wdf_rdy;   // beat1 accepted => store done

//  assign alexFinishedCommand   = read_ack || write_ack;
//  assign processingAlexCommand = (state != IDLE);

//  always_ff @(posedge clk) begin
//    if (reset) begin
//      state      <= IDLE;
//      wr_block   <= 1'b0;
//      last_waddr <= '0;
//    end else begin
//      // release the de-dup block once the store request drops or moves on
//      if (~is_write || alexAddress != last_waddr)
//        wr_block <= 1'b0;

//      case (state)
//        IDLE: begin
//          if (issue_write && ram_rdy && ram_wdf_rdy) begin
//            // command + beat0 both accepted this cycle
//            last_waddr <= alexAddress;
//            state      <= WR_B1;
//          end
//        end
//        WR_B1: begin
//          if (ram_wdf_rdy) begin              // beat1 accepted -> store committed
//            state    <= IDLE;
//            wr_block <= 1'b1;
//          end
//        end
//      endcase
//    end
//  end

//endmodule


module ram_reader #(
  parameter int ADDR_WIDTH      = 27,
  parameter bit HIGH_HALF_FIRST = 1'b1,
  parameter int STORE_GAP       = 1     // dead cycles forced after a store, before the next command
)(
  input  logic                  clk,
  input  logic                  reset,

  // ---- MIG native user interface ----
  output logic [ADDR_WIDTH-1:0] ram_address,
  output logic [2:0]            ram_cmd,
  output logic                  ram_en,
  input  logic                  ram_rdy,
  input  logic                  ram_rd_valid,
  input  logic                  ram_rd_data_end,
  input  logic [63:0]           ram_rd_data,
  output logic [63:0]           ram_wdf_data,
  output logic                  ram_wdf_wren,
  output logic                  ram_wdf_end,
  output logic [7:0]            ram_wdf_mask,
  input  logic                  ram_wdf_rdy,

  // ---- alex side ----
  input  logic [ADDR_WIDTH-1:0] alexAddress,
  input  logic [127:0]          alexWriteData,
  output logic [127:0]          alexReadData,
  output logic                  alexFinishedAction,   // -> alexFinishedMemAction
  input  logic [1:0]            alexMemEnable,
  input  logic [15:0]           alexWriteBytes,
  input  logic                  alexNewCommand,
  output logic                  alexFinishedCommand,  // -> alexCommandAcknowledged
  output logic                  processingAlexCommand,
  output logic [15:0] led
);

  localparam logic [2:0] CMD_WRITE = 3'b000;
  localparam logic [2:0] CMD_READ  = 3'b001;

  wire is_write = alexNewCommand &&  alexMemEnable[1];
  wire is_read  = alexNewCommand &&  alexMemEnable[0] && ~alexMemEnable[1];

  // =========================================================================
  // READ DATA PATH  (unchanged)
  // =========================================================================
  logic [63:0] rd_hi;
  always_ff @(posedge clk) begin
    if (reset)                                  rd_hi <= 64'd0;
    else if (ram_rd_valid && !ram_rd_data_end)  rd_hi <= ram_rd_data;
  end
  assign alexReadData       = HIGH_HALF_FIRST ? {rd_hi, ram_rd_data}
                                              : {ram_rd_data, rd_hi};
  assign alexFinishedAction = ram_rd_valid && ram_rd_data_end;
  typedef enum logic [1:0] { IDLE, WR_B1, WR_GAP } cstate_t;
  cstate_t        state;

  wire issue_write = is_write;   // no de-dup needed; only sampled in IDLE

  // first beat in IDLE, second beat in WR_B1
  logic [63:0] beat_data;
  logic [7:0]  beat_mask;
  always_comb begin
    if (state == WR_B1) begin
      beat_data = HIGH_HALF_FIRST ? alexWriteData[63:0]   : alexWriteData[127:64];
      beat_mask = HIGH_HALF_FIRST ? alexWriteBytes[7:0]   : alexWriteBytes[15:8];
    end else begin
      beat_data = HIGH_HALF_FIRST ? alexWriteData[127:64] : alexWriteData[63:0];
      beat_mask = HIGH_HALF_FIRST ? alexWriteBytes[15:8]  : alexWriteBytes[7:0];
    end
  end
    assign ram_wdf_mask = beat_mask;
  always_comb begin
    ram_address  = {alexAddress[ADDR_WIDTH-1:3], 3'b000};
    ram_cmd      = (alexMemEnable[1] || state != IDLE) ? CMD_WRITE : CMD_READ;
    ram_wdf_data = beat_data;

    ram_en       = 1'b0;
    ram_wdf_wren = 1'b0;
    ram_wdf_end  = 1'b0;

    if (state == IDLE) begin
      if (is_read) begin
        ram_en = 1'b1;                       // pipelined read; accepted on ram_rdy
      end else if (issue_write) begin
        ram_en       = ram_wdf_rdy;          // command only if WDF can take beat0
        ram_wdf_wren = ram_rdy;              // beat0 only if command will be taken
        ram_wdf_end  = 1'b0;
      end
    end else if (state == WR_B1) begin
      ram_wdf_wren = 1'b1;                    // second beat
      ram_wdf_end  = 1'b1;
    end
    // WR_GAP: command/data bus held idle (all strobes 0)
  end

  wire read_ack  = (state == IDLE)  && is_read && ram_rdy;
  wire write_ack = (state == WR_GAP);   // ack fires at commit, NOT after the gap

  assign alexFinishedCommand   = read_ack || write_ack;
  assign processingAlexCommand = (state != IDLE);

  always_ff @(posedge clk) begin
    if (reset) begin
      state   <= IDLE;
    end else begin
      case (state)
        IDLE: begin
          if (issue_write && ram_rdy && ram_wdf_rdy) begin
            state <= WR_B1;
          end
        end
        WR_B1: begin
          if (ram_wdf_rdy) begin              // beat1 accepted -> store committed
            if (STORE_GAP == 0) state <= IDLE;
            else begin
              state   <= WR_GAP;
            end
          end
        end
        WR_GAP: begin                          // forced cooldown before the next command
           state <= IDLE;
        end
      endcase
    end
  end
    logic [15:0] x;
    always_ff @(posedge clk) begin
        if(reset) begin
            x <= '0;
        end
        else if ((alexFinishedCommand && alexAddress[26:3] % 'd160 == '0 && alexWriteBytes[3:0] == 4'b0000 && alexWriteData[31:8] == 24'h0055AA && alexMemEnable[1])) begin
            x <= x + 1;
        end
    end
//    assign led[15:8] = x[7:0];
//    assign led[7:0] = x[7:0];
    assign led = x;
endmodule
