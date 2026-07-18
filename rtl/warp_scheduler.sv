//module gpuCoreCluster #(
//    parameter NUM_CORES = 16,
//    parameter QUEUE_SIZE = 1024
//)(
//    input  logic        clk,
//    input  logic        rst,

//    // New instruction interface
//    input  logic [31:0] new_inst,         // incoming instruction from fetch stage
//    input  logic        new_inst_valid,   // indicates if new_inst is valid
//    output logic        fetch_queue_full, // signals frontend that queue is full

//    // Backend interfaces for all cores (each has independent divide/load/store units)
//    output logic [NUM_CORES-1:0][31:0] div_reg0,
//    output logic [NUM_CORES-1:0][31:0] div_reg1,
//    output logic [NUM_CORES-1:0]       should_divide,
//    input  logic [NUM_CORES-1:0][31:0] div_result,
//    input  logic [NUM_CORES-1:0]       div_finished,

//    output logic [NUM_CORES-1:0][31:0] store_addr,
//    output logic [NUM_CORES-1:0][31:0] store_value,
//    output logic [NUM_CORES-1:0][3:0]  store_we,
//    output logic [NUM_CORES-1:0]       store_enable,
//    input  logic [NUM_CORES-1:0]       store_finished,

//    output logic [NUM_CORES-1:0][31:0] load_addr,
//    input  logic [NUM_CORES-1:0]       load_acknowledged,
//    input  logic [NUM_CORES-1:0]       load_finished,
//    input  logic [NUM_CORES-1:0][31:0] load_value,
//    output logic [NUM_CORES-1:0][7:0] load_command_id,
//    input logic [NUM_CORES-1:0][7:0] load_finished_id,
//    input logic live_cpu_stores,
//    output logic [NUM_CORES-1:0]       should_load,
    
//    output logic [31:0] ibuf_fill,
//    output logic [15:0] led
    
//);
//    logic [3:0] modulo_wrapper;
//    logic [31:0] decode_pipe_imm;
//    logic [2:0]  decode_pipe_aluop;
//    logic        decode_pipe_alu;
//    logic        decode_pipe_mul;
//    logic        decode_pipe_load;
//    logic        decode_pipe_store;
//    logic        decode_pipe_divide;
//    logic [3:0]  decode_pipe_dr;
//    logic [2:0]  decode_pipe_nzp;
//    logic [2:0]  decode_pipe_shift_amt;
//    logic [5:0]  instructions_to_skip;
//    logic        decode_pipe_shared;
//    logic [3:0]  decode_pipe_byte_enable;
    
//    logic [NUM_CORES - 1:0][15:0] live_in_progress;

//    logic [NUM_CORES - 1:0][15:0][5:0] coresWaiting;

//    // Context outputs from each core
//    logic [NUM_CORES-1:0][3:0] mul_output_ctx, div_ctx_write;
//    logic [NUM_CORES-1:0] div_write, div_busy, load_busy, load_wait_busy, store_busy, dont_dispatch_mul, freeze_alu, mul_write, alu_waiting;
//    logic [15:0] modulo_less_than, barrier_ctx;

//    logic [3:0] cur_ctx, next_ctx, next_ctx_plus_one;
//    logic [$clog2(QUEUE_SIZE) - 1 : 0] head, tail, lastPC, difference;
//    logic [15:0][$clog2(QUEUE_SIZE) - 1 : 0] ctx_pc;
//    logic [$clog2(QUEUE_SIZE) - 1 : 0] next_pc_ctx;
//    logic trash_inst, skip_ctx, on_head;
//    integer loop_barriers;
//    assign difference = tail - head;
//    assign ibuf_fill = {{32 - $clog2(QUEUE_SIZE){1'b0}}, difference};
//    logic [3:0] opcode, prev_ctx;
//    logic [31:0] imm_ext;
//    logic [2:0] aluop;
//    logic [2:0] nzp;
//    logic [2:0] shift_amt;
//    logic [5:0] skip_amt;
//    logic        shared, divide, load, store, mul, alu, use_imm, old_trash_inst;
//    logic [3:0]  dr, sr1, sr2;
//    logic [3:0]  byte_enable;
//    logic [31:0] instruction;
//    logic [4:0] cur_ctx_clocks;
//    assign opcode = instruction[31:28];
//    logic [NUM_CORES - 1: 0] live_ctx_match, waiting_store;
//    logic decode_pipe_use_imm, div_unit_occupied, load_unit_occupied, store_unit_occupied, alu_occupied, store_live;    
//    logic [3:0] alu_ctx_register;
//    logic old_barrier_activate;
//    logic wrap_plus_two, wrap_plus_one, wrap_plus_three;
//    logic [7:0] decode_pipe_sr1, decode_pipe_sr2;
    
//    logic [15:0] ahead_output;
//    logic ahead_match, modulo_wrapper_two, modulo_wrapper_one, barrier_wait, barrier_proceed;
//    assign ahead_match = (ahead_output[2] & div_unit_occupied) || (ahead_output[0] & (|store_busy || decode_pipe_store)) ||
//        (ahead_output[1] && load_unit_occupied) || (ahead_output[3] && mul && ~trash_inst);
//    always_ff @(posedge clk) begin
//        if(rst) begin
//            head <= '0;
//            tail <= '0;
//            ctx_pc <= '0;
//        end
//        else begin
//            if(!on_head && new_inst_valid) begin
//                head <= head + 1;
//                tail <= tail + 1;
//            end
//            else if (new_inst_valid && !fetch_queue_full) begin
//                tail <= tail + 1;
//            end
//            else if (!on_head && !new_inst_valid) begin
//                head <= head + 1;
//            end
            
            
//            if(barrier_proceed) begin
//                for(loop_barriers = 0; loop_barriers < 16; loop_barriers += 1) begin
//                    ctx_pc[loop_barriers] <= ctx_pc[cur_ctx] + 1;
//                end
//            end
//            else
//                ctx_pc[cur_ctx] <= next_pc_ctx;
//        end
//    end

//    assign fetch_queue_full = tail + 1 == head;
//    always_comb begin
//        // Default values
//        aluop        = 3'b000;
//        alu          = 1'b0;
//        mul          = 1'b0;
//        load         = 1'b0;
//        store        = 1'b0;
//        divide       = 1'b0;
//        shared       = 1'b0;
//        byte_enable  = 4'b1111;
//        dr           = instruction[27:24];
//        sr1          = instruction[23:20];
//        sr2          = 'x;
//        imm_ext      = 'x;
//        nzp          = 3'b000;
//        shift_amt    = 3'b000;
//        skip_amt     = 6'b000000;
//        use_imm      = '0;


//        case (opcode)

//            // 0000: ADD / SUB
//            4'b0000: begin
//                alu   = 1'b1;
//                aluop = instruction[18] ? 3'b001 : 3'b000; // 0=ADD,1=SUB
//                sr2   = instruction[17:14];
//                imm_ext = {{14{instruction[17]}}, instruction[17:0]}; // use all remaining bits
//                use_imm = instruction[19];
//            end

//            // 0001: AND / OR
//            4'b0001: begin
//                alu   = 1'b1;
//                aluop = instruction[18] ? 3'b110 : 3'b101; // 010=AND,011=OR
//                use_imm = instruction[19];
//                sr2   = instruction[17:14];
//                imm_ext = {{15{instruction[17]}}, instruction[16:0]}; // zero-extended immediate
//            end

//            // 0010: XOR
//            4'b0010: begin
//                alu   = 1'b1;
//                aluop = 3'b111;
//                use_imm = instruction[19];
//                sr2   = instruction[18:15];
//                imm_ext = {{14{instruction[17]}}, instruction[17:0]}; // zero-extended immediate
//            end

//            // 0011: MULTIPLY
//            4'b0011: begin
//                mul = 1'b1;
//                imm_ext = {{13{instruction[18]}}, instruction[18:0]};
//                use_imm = instruction[19];
//                sr2 = instruction[18:15];
//            end

//            // 0100: DIVIDE
//            4'b0100: begin
//                divide = 1'b1;
//                imm_ext = {{13{instruction[18]}}, instruction[18:0]};
//                use_imm = instruction[19];
//                sr2 = instruction[18:15];
//            end

//            // 0101: BIT SHIFT
//            4'b0101: begin
//                alu   = 1'b1;
//                shift_amt = instruction[17:15];
//                case(instruction[19:18])
//                    2'b00: aluop = 3'b010;
//                    2'b01: aluop = 3'b011;
//                    2'b10: aluop = 3'b100;
//                    default: aluop = 3'b010;
//                endcase
//                use_imm = '1;
//            end

//            // 0110: COMPARE IMMEDIATE
//            4'b0110: begin
//                alu   = 1'b1;
//                aluop = 3'b001;
//                nzp   = ~instruction[23:21];
//                skip_amt = instruction[20:15]; // 6-bit instruction skip
//                imm_ext  = {{17{instruction[14]}}, instruction[14:0]};
//                use_imm = '1;
//                sr1 = instruction[27:24];
//            end

//            // 0111: COMPARE DUAL-SOURCE
//            4'b0111: begin
//                sr1 = instruction[27:24];
//                alu   = 1'b1;
//                aluop = 3'b001;
//                nzp   = ~instruction[19:17];
//                sr2   = instruction[23:20];
//                skip_amt = instruction[16:11];
//                use_imm = '0;
//            end

//            // 1000: LOAD SHARED 
//            4'b1000: begin
//                load   = 1'b1;
//                shared = 1'b1;
//                aluop = 3'b000;
//                use_imm = instruction[19];
//                sr2 = instruction[18:15];
//                imm_ext = {{13{instruction[18]}}, instruction[18:0]};
//            end

//            // 1001: LOAD GLOBAL 
//            4'b1001: begin
//                load   = 1'b1;
//                shared = 1'b0;
//                aluop = 3'b000;
//                use_imm = instruction[19];
//                sr2 = instruction[18:15];
//                imm_ext = {{13{instruction[18]}}, instruction[18:0]};
//            end

//            // 1010: STORE SHARED (SR2 + IMM)
//            4'b1010: begin
//                store  = 1'b1;
//                shared = 1'b1;
//                use_imm = '1;
//                aluop = 3'b000;
//                imm_ext = {{16{instruction[15]}}, instruction[15:0]}; // maximize immediate bits
//                byte_enable = instruction[19:16];
//                sr2 = instruction[23:20];
//                sr1 = instruction[27:24];
//            end

//            // 1011: STORE GLOBAL (SR2 + IMM)
//            4'b1011: begin
//                store  = 1'b1;
//                shared = 1'b0;
//                use_imm = '1;
//                aluop = 3'b000;
//                byte_enable = instruction[19:16];
//                imm_ext = {{16{instruction[15]}}, instruction[15:0]}; // maximize immediate bits
//                sr2 = instruction[23:20];
//                alu = 1'b0;
//                sr1 = instruction[27:24];
//            end

//            4'b1110: begin // SLT (or SLTE)
//                alu   = 1'b1;
//                sr2   = instruction[17:14];
//                imm_ext = {{14{instruction[17]}}, instruction[17:0]}; // use all remaining bits
//                use_imm = instruction[19];
//                aluop = 3'b001;
//                shift_amt[2:1] = 2'b11;
//                shift_amt[0] = instruction[18];
//            end
//            default: begin
//                alu   = 1'b0;
//                mul   = 1'b0;
//                load  = 1'b0;
//                store = 1'b0;
//                divide= 1'b0;
//            end
//        endcase
//    end
//    logic all_live_in_progress;
//    always_comb begin
//        barrier_wait = opcode == 4'b1111 && ~(&(barrier_ctx | modulo_less_than) && ~(store_live || 
//            |freeze_alu || all_live_in_progress));
    
//        barrier_proceed = opcode == 4'b1111 && (&(barrier_ctx | modulo_less_than) && ~(store_live || 
//            |freeze_alu || all_live_in_progress));
            
//        for (integer i = 0; i < NUM_CORES; i++) begin
//            live_ctx_match[i]  = live_in_progress[i][cur_ctx];
//        end
//        trash_inst = (div_unit_occupied && divide) || old_barrier_activate || |live_ctx_match || 
//            (|alu_waiting && alu_ctx_register == cur_ctx) || (load && load_unit_occupied) || (|freeze_alu && prev_ctx == cur_ctx) ||
//            (store && store_unit_occupied) || (mul && |dont_dispatch_mul) ||
//            tail == lastPC || (|freeze_alu && alu) || opcode == 4'b1111 || ctx_pc[cur_ctx] == tail;
            
//        skip_ctx = trash_inst || mul || divide || load || store || &cur_ctx_clocks || opcode[3:1] == 3'b011;


//        if(trash_inst)
//            next_pc_ctx = ctx_pc[cur_ctx];
//        else
//            next_pc_ctx = ctx_pc[cur_ctx] + 1;
            
//        if(skip_ctx && ~modulo_wrapper_one) begin
//            if(ahead_match && ~modulo_wrapper_two) begin
//                if(wrap_plus_two)
//                    next_ctx = cur_ctx + 1 - modulo_wrapper;
//                else
//                    next_ctx = cur_ctx + 2;
                    
//                if(wrap_plus_three)
//                    next_ctx_plus_one = cur_ctx + 2 - modulo_wrapper;
//                else
//                    next_ctx_plus_one = cur_ctx + 3;
//            end
//            else begin
//                if(wrap_plus_one)
//                    next_ctx = cur_ctx - modulo_wrapper;
//                else
//                    next_ctx = cur_ctx + 1;
                    
//                if(wrap_plus_two)
//                    next_ctx_plus_one = cur_ctx + 1 - modulo_wrapper;
//                else
//                    next_ctx_plus_one = cur_ctx + 2;
//            end
//        end
//        else begin
//            next_ctx = cur_ctx;
//            if(cur_ctx + 1 > modulo_wrapper)
//                next_ctx_plus_one = cur_ctx - modulo_wrapper;
//            else
//                next_ctx_plus_one = cur_ctx + 1;
//        end
                    
//    end
//    integer alexInt;
//    always_ff @(posedge clk) begin
//        if(rst) begin
//            cur_ctx_clocks <= '0;
//            lastPC <= '0;
//            decode_pipe_use_imm <= '0;
//            barrier_ctx <= '0;
//            live_in_progress <= '0;
//            prev_ctx <= '0;
//            old_barrier_activate <= '0;
//            all_live_in_progress <= '0;
//        end
//        else begin
//            all_live_in_progress <= |live_in_progress;
//            old_barrier_activate <= barrier_proceed;
//            prev_ctx <= cur_ctx;
//            for(alexInt = 0; alexInt < NUM_CORES; alexInt++) begin
//                if(~trash_inst && (load || mul || divide)) begin
//                    live_in_progress[alexInt][cur_ctx] <= coresWaiting[alexInt][cur_ctx][5:1] == '0 && 
//                        (~coresWaiting[alexInt][cur_ctx][0] || (~old_trash_inst && prev_ctx == cur_ctx));
//                end
//                if(load_finished[alexInt])
//                    live_in_progress[alexInt][load_finished_id[alexInt][7:4]] <= '0;
//                if(mul_write[alexInt])
//                    live_in_progress[alexInt][mul_output_ctx[alexInt]] <= '0;
//                if(div_write[alexInt])
//                    live_in_progress[alexInt][div_ctx_write[alexInt]] <= '0;
//            end
        
        
//            if(skip_ctx) 
//                cur_ctx_clocks <= 0;
//            else 
//                cur_ctx_clocks <= cur_ctx_clocks + 1;


                
//            lastPC <= (skip_ctx) ? ctx_pc[next_ctx] : ctx_pc[cur_ctx] + 1;
//            decode_pipe_use_imm <= use_imm;
            

                
//            if (barrier_proceed) 
//                barrier_ctx <= '0;
//            else if(opcode == 4'b1111) 
//                barrier_ctx[cur_ctx] <= '1;
                
                
                

//        end
//    end

//    always_ff @(posedge clk) begin
//        old_trash_inst <= trash_inst;
//        div_unit_occupied <= |(div_busy & ~div_finished) || (~trash_inst && divide) || decode_pipe_divide;

////        load_unit_occupied <= |(({32{decode_pipe_load}} & load_busy) | 
////             ({32{decode_pipe_load}} & load_wait_busy) | 
////             (load_wait_busy & load_busy));
             
//        load_unit_occupied <= ~(&(({NUM_CORES{!(~trash_inst && load)}} & {NUM_CORES{!decode_pipe_load}} & ~load_busy) | 
//                 ({NUM_CORES{!(~trash_inst && load)}} & {NUM_CORES{!decode_pipe_load}} & ~load_wait_busy) | 
//                 ({NUM_CORES{!(~trash_inst && load)}} & ~load_wait_busy & ~load_busy) | 
//                 (~load_wait_busy & {NUM_CORES{!decode_pipe_load}} & ~load_busy)));

////        store_unit_occupied <= ~(&(({NUM_CORES{!(~trash_inst && store)}} & {NUM_CORES{!decode_pipe_store}} & ~store_enable) | 
////                 ({NUM_CORES{!(~trash_inst && store)}} & {NUM_CORES{!decode_pipe_store}} & ~waiting_store) | 
////                 ({NUM_CORES{!(~trash_inst && store)}} & ~waiting_store & ~store_enable) | 
////                 (~waiting_store & {NUM_CORES{!decode_pipe_store}} & ~store_enable)));        
//        store_unit_occupied <= (~trash_inst && store) || decode_pipe_store || |waiting_store || |store_enable;        
//        store_live <= (~trash_inst && store) || decode_pipe_store || |store_enable || |waiting_store || live_cpu_stores;
//        alu_occupied <= |freeze_alu;
        
//        if(~alu_occupied && |freeze_alu)
//            alu_ctx_register <= prev_ctx;
        
        
//        if (rst) begin
//            decode_pipe_alu          <= 1'b0;
//            decode_pipe_mul          <= 1'b0;
//            decode_pipe_load         <= 1'b0;
//            decode_pipe_store        <= 1'b0;
//            decode_pipe_divide       <= 1'b0;
//            decode_pipe_dr           <= 4'b0;
//            decode_pipe_nzp          <= 3'b0;
//            modulo_wrapper <= 4'b1111;
//            modulo_wrapper_two <= '0;
//            modulo_wrapper_one <= '0;
//            cur_ctx <= 0;
//            wrap_plus_two <= '0;
//            wrap_plus_one <= '0;
//            wrap_plus_three <= '0;
//        end 
//        else begin
//            wrap_plus_two <= next_ctx + 2 > modulo_wrapper;
//            wrap_plus_one <= next_ctx + 1 > modulo_wrapper;
//            wrap_plus_three <= next_ctx + 3 > modulo_wrapper;
//            if (barrier_proceed || old_barrier_activate)
//                cur_ctx <= '0;
//            else
//                cur_ctx <= next_ctx;
        
        
//            decode_pipe_alu          <= alu  & ~trash_inst;
//            decode_pipe_mul          <= mul & ~trash_inst;
//            decode_pipe_load         <= load & ~trash_inst;
//            decode_pipe_store        <= store & ~trash_inst;
//            decode_pipe_divide       <= divide & ~trash_inst;
//            decode_pipe_dr           <= dr;
//            decode_pipe_nzp          <= nzp;
            
//            if(barrier_proceed) begin
//                modulo_wrapper <= instruction[3:0];
//                modulo_wrapper_two <= instruction[3:0] == 4'b0001;
//                modulo_wrapper_one <= instruction[3:0] == 4'b0000;            
                
//            end 
//        end
//        decode_pipe_shift_amt    <= shift_amt;
//        instructions_to_skip     <= skip_amt;
//        decode_pipe_shared       <= shared;
//        decode_pipe_byte_enable  <= byte_enable;
//        decode_pipe_imm          <= imm_ext;
//        decode_pipe_aluop        <= aluop;
//    end

//    logic [31:0][31:0] sr1_value, sr2_value, dr_value;
//    logic [31:0][7:0] dr_sel, sr1_sel, sr2_sel;
//    logic [31:0] dr_en;
//    logic [15:0] ctx_on_head;
    
//    integer ak;
//    always_comb begin
//        for(ak = 0; ak < 16; ak++) begin
//            modulo_less_than[ak] = ak > modulo_wrapper;
//            ctx_on_head[ak] = head == ctx_pc[ak];
//        end   
//    end
//    assign on_head = |ctx_on_head;
//    logic [NUM_CORES -1 : 0] core_leds;
//    genvar i;
//    generate
//        for (i = 0; i < NUM_CORES; i++) begin : core_array

//            CoreInstructionInterface core_inst (
//                .clk(clk),
//                .rst(rst),

//                .decode_pipe_divide(decode_pipe_divide),
//                .decode_pipe_load(decode_pipe_load),
//                .decode_pipe_store(decode_pipe_store),
//                .decode_pipe_mul(decode_pipe_mul),
//                .decode_pipe_alu(decode_pipe_alu),
//                .decode_pipe_aluop({decode_pipe_use_imm, decode_pipe_aluop}),
//                .ctx(cur_ctx),
//                .decode_pipe_imm(decode_pipe_imm),
//                .src1_id(sr1),
//                .src2_id(sr2),
//                .decode_pipe_dr(decode_pipe_dr),
//                .decode_pipe_shift_amt(decode_pipe_shift_amt),
//                .instructions_to_skip(instructions_to_skip),
//                .decode_pipe_nzp(decode_pipe_nzp),
//                .decode_pipe_shared(decode_pipe_shared),
//                .decode_pipe_byte_enable(decode_pipe_byte_enable),

//                .div_busy(div_busy[i]),
//                .load_busy(load_busy[i]),
//                .store_busy(store_busy[i]),
//                .waiting_load(load_wait_busy[i]),

//                .div_reg0(div_reg0[i]),
//                .div_reg1(div_reg1[i]),
//                .should_divide(should_divide[i]),
//                .div_result(div_result[i]),
//                .div_finished(div_finished[i]),

//                .store_addr(store_addr[i]),
//                .store_value(store_value[i]),
//                .store_we(store_we[i]),
//                .store_enable(store_enable[i]),
//                .store_finished(store_finished[i]),

//                .load_addr(load_addr[i]),
//                .load_finished(load_finished[i]),
//                .load_value(load_value[i]),
//                .should_load(should_load[i]),
//                .finished_load_id(load_finished_id[i]),
//                .load_command_id(load_command_id[i]),
//                .load_acknowledged(load_acknowledged[i]),

//                .sr1_sel(sr1_sel[i]), 
//                .sr2_sel(sr2_sel[i]),
//                .sr1_in(sr1_value[i]), 
//                .sr2_in(sr2_value[i]), 
//                .dr_sel(dr_sel[i]), 
//                .dr(dr_value[i]), 
//                .dr_en(dr_en[i]),
//                .ctx_instruction_skip(coresWaiting[i]),
//                .freeze_alu(freeze_alu[i]),
//                .dont_dispatch_mul(dont_dispatch_mul[i]),
//                .mul_output_ctx(mul_output_ctx[i]),
//                .mul_write(mul_write[i]),
//                .alu_waiting(alu_waiting[i]),
//                .div_ctx(div_ctx_write[i]),
//                .div_write(div_write[i]),
//                .waiting_store(waiting_store[i]),
//                .led(core_leds[i]),
//                .decode_pipe_sr1(decode_pipe_sr1),
//                .decode_pipe_sr2(decode_pipe_sr2)
//            );
//        end
//    endgenerate
//    always_ff @(posedge clk) begin
//        decode_pipe_sr1 <= sr1_sel[0];
//        decode_pipe_sr2 <= sr2_sel[0];
//    end
//twoReadOneWriteRegFile_0 a(.clk,.rst,.sr1_sel(sr1_sel[0]),.sr2_sel(sr2_sel[0]),
//                          .sr1(sr1_value[0]),.sr2(sr2_value[0]),.dr_sel(dr_sel[0]),.dr(dr_value[0]),.dr_en(dr_en[0]));

//twoReadOneWriteRegFile_1 b(.clk,.rst,.sr1_sel(sr1_sel[1]),.sr2_sel(sr2_sel[1]),
//                          .sr1(sr1_value[1]),.sr2(sr2_value[1]),.dr_sel(dr_sel[1]),.dr(dr_value[1]),.dr_en(dr_en[1]));

//twoReadOneWriteRegFile_2 c(.clk,.rst,.sr1_sel(sr1_sel[2]),.sr2_sel(sr2_sel[2]),
//                          .sr1(sr1_value[2]),.sr2(sr2_value[2]),.dr_sel(dr_sel[2]),.dr(dr_value[2]),.dr_en(dr_en[2]));

//twoReadOneWriteRegFile_3 d(.clk,.rst,.sr1_sel(sr1_sel[3]),.sr2_sel(sr2_sel[3]),
//                          .sr1(sr1_value[3]),.sr2(sr2_value[3]),.dr_sel(dr_sel[3]),.dr(dr_value[3]),.dr_en(dr_en[3]));

//twoReadOneWriteRegFile_4 e(.clk,.rst,.sr1_sel(sr1_sel[4]),.sr2_sel(sr2_sel[4]),
//                          .sr1(sr1_value[4]),.sr2(sr2_value[4]),.dr_sel(dr_sel[4]),.dr(dr_value[4]),.dr_en(dr_en[4]));

//twoReadOneWriteRegFile_5 f(.clk,.rst,.sr1_sel(sr1_sel[5]),.sr2_sel(sr2_sel[5]),
//                          .sr1(sr1_value[5]),.sr2(sr2_value[5]),.dr_sel(dr_sel[5]),.dr(dr_value[5]),.dr_en(dr_en[5]));

//twoReadOneWriteRegFile_6 g(.clk,.rst,.sr1_sel(sr1_sel[6]),.sr2_sel(sr2_sel[6]),
//                          .sr1(sr1_value[6]),.sr2(sr2_value[6]),.dr_sel(dr_sel[6]),.dr(dr_value[6]),.dr_en(dr_en[6]));

//twoReadOneWriteRegFile_7 h(.clk,.rst,.sr1_sel(sr1_sel[7]),.sr2_sel(sr2_sel[7]),
//                          .sr1(sr1_value[7]),.sr2(sr2_value[7]),.dr_sel(dr_sel[7]),.dr(dr_value[7]),.dr_en(dr_en[7]));

//twoReadOneWriteRegFile_8 ai(.clk,.rst,.sr1_sel(sr1_sel[8]),.sr2_sel(sr2_sel[8]),
//                           .sr1(sr1_value[8]),.sr2(sr2_value[8]),.dr_sel(dr_sel[8]),.dr(dr_value[8]),.dr_en(dr_en[8]));

//twoReadOneWriteRegFile_9 j(.clk,.rst,.sr1_sel(sr1_sel[9]),.sr2_sel(sr2_sel[9]),
//                          .sr1(sr1_value[9]),.sr2(sr2_value[9]),.dr_sel(dr_sel[9]),.dr(dr_value[9]),.dr_en(dr_en[9]));

//twoReadOneWriteRegFile_10 k(.clk,.rst,.sr1_sel(sr1_sel[10]),.sr2_sel(sr2_sel[10]),
//                           .sr1(sr1_value[10]),.sr2(sr2_value[10]),.dr_sel(dr_sel[10]),.dr(dr_value[10]),.dr_en(dr_en[10]));

//twoReadOneWriteRegFile_11 l(.clk,.rst,.sr1_sel(sr1_sel[11]),.sr2_sel(sr2_sel[11]),
//                           .sr1(sr1_value[11]),.sr2(sr2_value[11]),.dr_sel(dr_sel[11]),.dr(dr_value[11]),.dr_en(dr_en[11]));

//twoReadOneWriteRegFile_12 m(.clk,.rst,.sr1_sel(sr1_sel[12]),.sr2_sel(sr2_sel[12]),
//                           .sr1(sr1_value[12]),.sr2(sr2_value[12]),.dr_sel(dr_sel[12]),.dr(dr_value[12]),.dr_en(dr_en[12]));

//twoReadOneWriteRegFile_13 n(.clk,.rst,.sr1_sel(sr1_sel[13]),.sr2_sel(sr2_sel[13]),
//                           .sr1(sr1_value[13]),.sr2(sr2_value[13]),.dr_sel(dr_sel[13]),.dr(dr_value[13]),.dr_en(dr_en[13]));

//twoReadOneWriteRegFile_14 o(.clk,.rst,.sr1_sel(sr1_sel[14]),.sr2_sel(sr2_sel[14]),
//                           .sr1(sr1_value[14]),.sr2(sr2_value[14]),.dr_sel(dr_sel[14]),.dr(dr_value[14]),.dr_en(dr_en[14]));

//twoReadOneWriteRegFile_15 p(.clk,.rst,.sr1_sel(sr1_sel[15]),.sr2_sel(sr2_sel[15]),
//                           .sr1(sr1_value[15]),.sr2(sr2_value[15]),.dr_sel(dr_sel[15]),.dr(dr_value[15]),.dr_en(dr_en[15]));

//twoReadOneWriteRegFile_16 q(.clk,.rst,.sr1_sel(sr1_sel[16]),.sr2_sel(sr2_sel[16]),
//                           .sr1(sr1_value[16]),.sr2(sr2_value[16]),.dr_sel(dr_sel[16]),.dr(dr_value[16]),.dr_en(dr_en[16]));
//twoReadOneWriteRegFile_17 r(.clk,.rst,.sr1_sel(sr1_sel[17]),.sr2_sel(sr2_sel[17]),
//                           .sr1(sr1_value[17]),.sr2(sr2_value[17]),.dr_sel(dr_sel[17]),.dr(dr_value[17]),.dr_en(dr_en[17]));
//twoReadOneWriteRegFile_18 s(.clk,.rst,.sr1_sel(sr1_sel[18]),.sr2_sel(sr2_sel[18]),
//                           .sr1(sr1_value[18]),.sr2(sr2_value[18]),.dr_sel(dr_sel[18]),.dr(dr_value[18]),.dr_en(dr_en[18]));
//twoReadOneWriteRegFile_19 t(.clk,.rst,.sr1_sel(sr1_sel[19]),.sr2_sel(sr2_sel[19]),
//                           .sr1(sr1_value[19]),.sr2(sr2_value[19]),.dr_sel(dr_sel[19]),.dr(dr_value[19]),.dr_en(dr_en[19]));

//    instructionBuf ibuf_inst (
//        .clka   (clk),
//        .ena    (new_inst_valid && ~fetch_queue_full),
//        .wea    (1'b1),
//        .addra  (tail),
//        .dina   (new_inst),

//        .clkb   (clk),
//        .enb    (1'b1),
//        .addrb  ((skip_ctx) ? ctx_pc[next_ctx] : ctx_pc[cur_ctx] + 1),
//        .doutb  (instruction)
//    );
//    integer xxx;
//    logic [NUM_CORES - 1:0] ooga;
//    always_comb begin
//        for(xxx = 0; xxx < NUM_CORES; xxx++)
//            ooga[xxx] = store_we[xxx] != 4'b1111;
//    end
//    assign led = core_leds[19:4];
//    iuop iuop_inst (
//        .clka   (clk),
//        .ena    (new_inst_valid && ~fetch_queue_full),
//        .wea    (1'b1),
//        .addra  (tail),
//        .dina   ({12'd0, new_inst[31:28] == 4'b0011, new_inst[31:28] == 4'b0100, new_inst[31:29] == 3'b100, new_inst[31:29] == 3'b101}),//div, load, store

//        .clkb   (clk),
//        .enb    (1'b1),
//        .addrb  (ctx_pc[next_ctx_plus_one]),
//        .doutb  (ahead_output)
//    );

//endmodule


module gpuCoreCluster #(
    parameter NUM_CORES = 16,
    parameter QUEUE_SIZE = 1024
)(
    input  logic        clk,
    input  logic        rst,

    // New instruction interface
    input  logic [31:0] new_inst,         // incoming instruction from fetch stage
    input  logic        new_inst_valid,   // indicates if new_inst is valid
    output logic        fetch_queue_full, // signals frontend that queue is full

    // Backend interfaces for all cores (each has independent divide/load/store units)
    output logic [NUM_CORES-1:0][31:0] div_reg0,
    output logic [NUM_CORES-1:0][31:0] div_reg1,
    output logic [NUM_CORES-1:0]       should_divide,
    input  logic [NUM_CORES-1:0][31:0] div_result,
    input  logic [NUM_CORES-1:0]       div_finished,

    output logic [NUM_CORES-1:0][31:0] store_addr,
    output logic [NUM_CORES-1:0][31:0] store_value,
    output logic [NUM_CORES-1:0][3:0]  store_we,
    output logic [NUM_CORES-1:0]       store_enable,
    input  logic [NUM_CORES-1:0]       store_finished,

    output logic [NUM_CORES-1:0][31:0] load_addr,
    input  logic [NUM_CORES-1:0]       load_acknowledged,
    input  logic [NUM_CORES-1:0]       load_finished,
    input  logic [NUM_CORES-1:0][31:0] load_value,
    output logic [NUM_CORES-1:0][7:0] load_command_id,
    input logic [NUM_CORES-1:0][7:0] load_finished_id,
    input logic live_cpu_stores,
    output logic [NUM_CORES-1:0]       should_load,
    
    output logic [31:0] ibuf_fill,
    output logic [15:0] led
    
);
    logic [3:0] modulo_wrapper;
    logic [31:0] decode_pipe_imm;
    logic [2:0]  decode_pipe_aluop;
    logic        decode_pipe_alu;
    logic        decode_pipe_mul;
    logic        decode_pipe_load;
    logic        decode_pipe_store;
    logic        decode_pipe_divide;
    logic [3:0]  decode_pipe_dr;
    logic [2:0]  decode_pipe_nzp;
    logic [2:0]  decode_pipe_shift_amt;
    logic [7:0]  instructions_to_skip;
    logic        decode_pipe_shared;
    logic [3:0]  decode_pipe_byte_enable;
    
    logic [NUM_CORES - 1:0][15:0] live_in_progress;

    logic [NUM_CORES - 1:0][15:0][6:0] coresWaiting;

    // Context outputs from each core
    logic [NUM_CORES-1:0][3:0] mul_output_ctx, div_ctx_write;
    logic [NUM_CORES-1:0] div_write, div_busy, load_busy, load_wait_busy, store_busy, dont_dispatch_mul, freeze_alu, mul_write, alu_waiting, live_divide;
    logic [15:0] modulo_less_than, barrier_ctx;

    logic [3:0] cur_ctx, next_ctx, next_ctx_plus_one;
    logic [$clog2(QUEUE_SIZE) - 1 : 0] head, tail, lastPC, difference, insert_tail;
    logic [15:0][$clog2(QUEUE_SIZE) - 1 : 0] ctx_pc;
    logic [$clog2(QUEUE_SIZE) - 1 : 0] next_pc_ctx;
    logic trash_inst, skip_ctx, on_head;
    integer loop_barriers;
    assign difference = tail - head;
    assign ibuf_fill = {{32 - $clog2(QUEUE_SIZE){1'b0}}, difference};
    logic [3:0] opcode, prev_ctx;
    logic [31:0] imm_ext;
    logic [2:0] aluop;
    logic [2:0] nzp;
    logic [2:0] shift_amt;
    logic [7:0] skip_amt;
    logic        shared, divide, load, store, mul, alu, use_imm, old_trash_inst;
    logic [3:0]  dr, sr1, sr2;
    logic [3:0]  byte_enable;
    logic [31:0] instruction;
    logic [4:0] cur_ctx_clocks;
    assign opcode = instruction[31:28];
    logic [NUM_CORES - 1: 0] live_ctx_match, waiting_store;
    logic decode_pipe_use_imm, div_unit_occupied, load_unit_occupied, store_unit_occupied, alu_occupied, store_live;    
    logic [3:0] alu_ctx_register;
    logic old_barrier_activate;
    logic wrap_plus_two, wrap_plus_one, wrap_plus_three;
    logic [7:0] decode_pipe_sr1, decode_pipe_sr2;
    
    logic [15:0] ahead_output;
    logic ahead_match, modulo_wrapper_two, modulo_wrapper_one, barrier_wait, barrier_proceed;
    assign ahead_match = (ahead_output[2] & div_unit_occupied) || (ahead_output[0] & (|store_busy || decode_pipe_store)) ||
        (ahead_output[1] && load_unit_occupied) || (ahead_output[3] && mul && ~trash_inst);
    always_ff @(posedge clk) begin
        if(rst) begin
            head <= '0;
            ctx_pc <= '0;
            insert_tail <= '0;
        end
        else begin
            if(!on_head && new_inst_valid) begin
                head <= head + 1;
                insert_tail <= insert_tail + 1;
            end
            else if (new_inst_valid && !fetch_queue_full) begin
                insert_tail <= insert_tail + 1;
            end
            else if (!on_head && !new_inst_valid) begin
                head <= head + 1;
            end
            
            
            if(barrier_proceed) begin
                for(loop_barriers = 0; loop_barriers < 16; loop_barriers += 1) begin
                    ctx_pc[loop_barriers] <= ctx_pc[cur_ctx] + 1;
                end
            end
            else
                ctx_pc[cur_ctx] <= next_pc_ctx;
        end
    end
    always_ff @(posedge clk) begin
        if(rst)
            tail <= '0;
        else
            tail <= insert_tail;
 
    
    end
    assign fetch_queue_full = (tail + 1) % QUEUE_SIZE  == head;
    always_comb begin
        // Default values
        aluop        = 3'b000;
        alu          = 1'b0;
        mul          = 1'b0;
        load         = 1'b0;
        store        = 1'b0;
        divide       = 1'b0;
        shared       = 1'b0;
        byte_enable  = 4'b1111;
        dr           = instruction[27:24];
        sr1          = instruction[23:20];
        sr2          = 'x;
        imm_ext      = 'x;
        nzp          = 3'b000;
        shift_amt    = 3'b000;
        skip_amt     = 8'b000000;
        use_imm      = '0;


        case (opcode)

            // 0000: ADD / SUB
            4'b0000: begin
                alu   = 1'b1;
                aluop = instruction[18] ? 3'b001 : 3'b000; // 0=ADD,1=SUB
                sr2   = instruction[17:14];
                imm_ext = {{14{instruction[17]}}, instruction[17:0]}; // use all remaining bits
                use_imm = instruction[19];
            end

            // 0001: AND / OR
            4'b0001: begin
                alu   = 1'b1;
                aluop = instruction[18] ? 3'b110 : 3'b101; // 010=AND,011=OR
                use_imm = instruction[19];
                sr2   = instruction[17:14];
                imm_ext = {{15{instruction[17]}}, instruction[16:0]}; // zero-extended immediate
            end

            // 0010: XOR
            4'b0010: begin
                alu   = 1'b1;
                aluop = 3'b111;
                use_imm = instruction[19];
                sr2   = instruction[18:15];
                imm_ext = {{14{instruction[17]}}, instruction[17:0]}; // zero-extended immediate
            end

            // 0011: MULTIPLY
            4'b0011: begin
                mul = 1'b1;
                imm_ext = {{13{instruction[18]}}, instruction[18:0]};
                use_imm = instruction[19];
                sr2 = instruction[18:15];
            end

            // 0100: DIVIDE
            4'b0100: begin
                divide = 1'b1;
                imm_ext = {{13{instruction[18]}}, instruction[18:0]};
                use_imm = instruction[19];
                sr2 = instruction[18:15];
            end

            // 0101: BIT SHIFT
            4'b0101: begin
                alu   = 1'b1;
                shift_amt = instruction[17:15];
                case(instruction[19:18])
                    2'b00: aluop = 3'b010;
                    2'b01: aluop = 3'b011;
                    2'b10: aluop = 3'b100;
                    default: aluop = 3'b010;
                endcase
                use_imm = '1;
            end

            // 0110: COMPARE IMMEDIATE
            4'b0110: begin
                alu   = 1'b1;
                aluop = 3'b001;
                nzp   = ~instruction[23:21];
                skip_amt = instruction[20:13]; // 6-bit instruction skip
                imm_ext  = {{19{instruction[12]}}, instruction[12:0]};
                use_imm = '1;
                sr1 = instruction[27:24];
            end

            // 0111: COMPARE DUAL-SOURCE
            4'b0111: begin
                sr1 = instruction[27:24];
                alu   = 1'b1;
                aluop = 3'b001;
                nzp   = ~instruction[19:17];
                sr2   = instruction[23:20];
                skip_amt = instruction[16:9];
                use_imm = '0;
            end

            // 1000: LOAD SHARED 
            4'b1000: begin
                load   = 1'b1;
                shared = 1'b1;
                aluop = 3'b000;
                use_imm = instruction[19];
                sr2 = instruction[18:15];
                imm_ext = {{13{instruction[18]}}, instruction[18:0]};
            end

            // 1001: LOAD GLOBAL 
            4'b1001: begin
                load   = 1'b1;
                shared = 1'b0;
                aluop = 3'b000;
                use_imm = instruction[19];
                sr2 = instruction[18:15];
                imm_ext = {{13{instruction[18]}}, instruction[18:0]};
            end

            // 1010: STORE SHARED (SR2 + IMM)
            4'b1010: begin
                store  = 1'b1;
                shared = 1'b1;
                use_imm = '1;
                aluop = 3'b000;
                imm_ext = {{16{instruction[15]}}, instruction[15:0]}; // maximize immediate bits
                byte_enable = instruction[19:16];
                sr2 = instruction[23:20];
                sr1 = instruction[27:24];
            end

            // 1011: STORE GLOBAL (SR2 + IMM)
            4'b1011: begin
                store  = 1'b1;
                shared = 1'b0;
                use_imm = '1;
                aluop = 3'b000;
                byte_enable = instruction[19:16];
                imm_ext = {{16{instruction[15]}}, instruction[15:0]}; // maximize immediate bits
                sr2 = instruction[23:20];
                alu = 1'b0;
                sr1 = instruction[27:24];
            end

            4'b1110: begin // SLT (or SLTE)
                alu   = 1'b1;
                sr2   = instruction[17:14];
                imm_ext = {{14{instruction[17]}}, instruction[17:0]}; // use all remaining bits
                use_imm = instruction[19];
                aluop = 3'b001;
                shift_amt[2:1] = 2'b11;
                shift_amt[0] = instruction[18];
            end
            default: begin
                alu   = 1'b0;
                mul   = 1'b0;
                load  = 1'b0;
                store = 1'b0;
                divide= 1'b0;
            end
        endcase
    end
    logic all_live_in_progress;
    always_comb begin
        barrier_wait = opcode == 4'b1111 && ~(&(barrier_ctx | modulo_less_than) && ~(store_live || 
            |freeze_alu || all_live_in_progress)) && tail != lastPC;
    
        barrier_proceed = opcode == 4'b1111 && (&(barrier_ctx | modulo_less_than) && ~(store_live || 
            |freeze_alu || all_live_in_progress)) && tail != lastPC;
            
        for (integer i = 0; i < NUM_CORES; i++) begin
            live_ctx_match[i]  = live_in_progress[i][cur_ctx];
        end
//        trash_inst = (div_unit_occupied && divide) || old_barrier_activate || |live_ctx_match || 
//            (|alu_waiting && alu_ctx_register == cur_ctx) || (load && load_unit_occupied) || (|freeze_alu && prev_ctx == cur_ctx) ||
//            (store && store_unit_occupied) || (mul && |dont_dispatch_mul) ||
//            tail == lastPC || (|freeze_alu && alu) || opcode == 4'b1111 || ctx_pc[cur_ctx] == tail;
        trash_inst = (div_unit_occupied && divide) || old_barrier_activate || |live_ctx_match || 
            (|alu_waiting && alu_ctx_register == cur_ctx) || (load && load_unit_occupied) || (|freeze_alu && prev_ctx == cur_ctx) ||
            (store && store_unit_occupied) || (mul && |dont_dispatch_mul) ||
            tail == lastPC || (|freeze_alu && alu) || opcode == 4'b1111;
            
        skip_ctx = trash_inst || mul || divide || load || store || &cur_ctx_clocks || opcode[3:1] == 3'b011;


        if(trash_inst)
            next_pc_ctx = ctx_pc[cur_ctx];
        else
            next_pc_ctx = ctx_pc[cur_ctx] + 1;
            
        if(skip_ctx && ~modulo_wrapper_one) begin
            if(ahead_match && ~modulo_wrapper_two) begin
                if(wrap_plus_two)
                    next_ctx = cur_ctx + 1 - modulo_wrapper;
                else
                    next_ctx = cur_ctx + 2;
                    
                if(wrap_plus_three)
                    next_ctx_plus_one = cur_ctx + 2 - modulo_wrapper;
                else
                    next_ctx_plus_one = cur_ctx + 3;
            end
            else begin
                if(wrap_plus_one)
                    next_ctx = cur_ctx - modulo_wrapper;
                else
                    next_ctx = cur_ctx + 1;
                    
                if(wrap_plus_two)
                    next_ctx_plus_one = cur_ctx + 1 - modulo_wrapper;
                else
                    next_ctx_plus_one = cur_ctx + 2;
            end
        end
        else begin
            next_ctx = cur_ctx;
            if(cur_ctx + 1 > modulo_wrapper)
                next_ctx_plus_one = cur_ctx - modulo_wrapper;
            else
                next_ctx_plus_one = cur_ctx + 1;
        end
                    
    end
    integer alexInt;
    assign all_live_in_progress = |live_in_progress;
    always_ff @(posedge clk) begin
        if(rst) begin
            cur_ctx_clocks <= '0;
            lastPC <= '0;
            decode_pipe_use_imm <= '0;
            barrier_ctx <= '0;
            live_in_progress <= '0;
            prev_ctx <= '0;
            old_barrier_activate <= '0;
        end
        else begin
            
            old_barrier_activate <= barrier_proceed;
            prev_ctx <= cur_ctx;
            for(alexInt = 0; alexInt < NUM_CORES; alexInt++) begin
                if(~trash_inst && (load || mul || divide)) begin
                    live_in_progress[alexInt][cur_ctx] <= coresWaiting[alexInt][cur_ctx][6:1] == '0 && 
                        (~coresWaiting[alexInt][cur_ctx][0] || (~old_trash_inst && prev_ctx == cur_ctx));
                end
                if(load_finished[alexInt])
                    live_in_progress[alexInt][load_finished_id[alexInt][7:4]] <= '0;
                if(mul_write[alexInt])
                    live_in_progress[alexInt][mul_output_ctx[alexInt]] <= '0;
                if(div_write[alexInt])
                    live_in_progress[alexInt][div_ctx_write[alexInt]] <= '0;
            end
        
        
            if(skip_ctx) 
                cur_ctx_clocks <= 0;
            else 
                cur_ctx_clocks <= cur_ctx_clocks + 1;


                
            lastPC <= (skip_ctx) ? ctx_pc[next_ctx] : ctx_pc[cur_ctx] + 1;
            decode_pipe_use_imm <= use_imm;
            

                
            if (barrier_proceed) 
                barrier_ctx <= '0;
            else if(opcode == 4'b1111) 
                barrier_ctx[cur_ctx] <= '1;
                
                
                

        end
    end

    always_ff @(posedge clk) begin
        old_trash_inst <= trash_inst;
        div_unit_occupied <= |live_divide || (~trash_inst && divide) || decode_pipe_divide;

//        load_unit_occupied <= |(({32{decode_pipe_load}} & load_busy) | 
//             ({32{decode_pipe_load}} & load_wait_busy) | 
//             (load_wait_busy & load_busy));
             
        load_unit_occupied <= ~(&(({NUM_CORES{!(~trash_inst && load)}} & {NUM_CORES{!decode_pipe_load}} & ~load_busy) | 
                 ({NUM_CORES{!(~trash_inst && load)}} & {NUM_CORES{!decode_pipe_load}} & ~load_wait_busy) | 
                 ({NUM_CORES{!(~trash_inst && load)}} & ~load_wait_busy & ~load_busy) | 
                 (~load_wait_busy & {NUM_CORES{!decode_pipe_load}} & ~load_busy)));

//        store_unit_occupied <= ~(&(({NUM_CORES{!(~trash_inst && store)}} & {NUM_CORES{!decode_pipe_store}} & ~store_enable) | 
//                 ({NUM_CORES{!(~trash_inst && store)}} & {NUM_CORES{!decode_pipe_store}} & ~waiting_store) | 
//                 ({NUM_CORES{!(~trash_inst && store)}} & ~waiting_store & ~store_enable) | 
//                 (~waiting_store & {NUM_CORES{!decode_pipe_store}} & ~store_enable)));        
        store_unit_occupied <= (~trash_inst && store) || decode_pipe_store || |waiting_store || |store_enable;        
        store_live <= (~trash_inst && store) || decode_pipe_store || |store_enable || |waiting_store || live_cpu_stores;
        alu_occupied <= |freeze_alu;
        
        if(~alu_occupied && |freeze_alu)
            alu_ctx_register <= prev_ctx;
        
        
        if (rst) begin
            decode_pipe_alu          <= 1'b0;
            decode_pipe_mul          <= 1'b0;
            decode_pipe_load         <= 1'b0;
            decode_pipe_store        <= 1'b0;
            decode_pipe_divide       <= 1'b0;
            decode_pipe_dr           <= 4'b0;
            decode_pipe_nzp          <= 3'b0;
            modulo_wrapper <= 4'b1111;
            modulo_wrapper_two <= '0;
            modulo_wrapper_one <= '0;
            cur_ctx <= 0;
            wrap_plus_two <= '0;
            wrap_plus_one <= '0;
            wrap_plus_three <= '0;
        end 
        else begin
            wrap_plus_two <= next_ctx + 2 > modulo_wrapper;
            wrap_plus_one <= next_ctx + 1 > modulo_wrapper;
            wrap_plus_three <= next_ctx + 3 > modulo_wrapper;
            if (barrier_proceed || old_barrier_activate)
                cur_ctx <= '0;
            else
                cur_ctx <= next_ctx;
        
        
            decode_pipe_alu          <= alu  & ~trash_inst;
            decode_pipe_mul          <= mul & ~trash_inst;
            decode_pipe_load         <= load & ~trash_inst;
            decode_pipe_store        <= store & ~trash_inst;
            decode_pipe_divide       <= divide & ~trash_inst;
            decode_pipe_dr           <= dr;
            decode_pipe_nzp          <= nzp;
            
            if(barrier_proceed) begin
                modulo_wrapper <= instruction[3:0];
                modulo_wrapper_two <= instruction[3:0] == 4'b0001;
                modulo_wrapper_one <= instruction[3:0] == 4'b0000;            
                
            end 
        end
        decode_pipe_shift_amt    <= shift_amt;
        instructions_to_skip     <= skip_amt;
        decode_pipe_shared       <= shared;
        decode_pipe_byte_enable  <= byte_enable;
        decode_pipe_imm          <= imm_ext;
        decode_pipe_aluop        <= aluop;
    end

    logic [31:0][31:0] sr1_value, sr2_value, dr_value;
    logic [31:0][7:0] dr_sel, sr1_sel, sr2_sel;
    logic [31:0] dr_en;
    logic [15:0] ctx_on_head;
    
    integer ak;
    always_comb begin
        for(ak = 0; ak < 16; ak++) begin
            modulo_less_than[ak] = ak > modulo_wrapper;
            ctx_on_head[ak] = head == ctx_pc[ak];
        end   
    end
    assign on_head = |(ctx_on_head & ~modulo_less_than);
    logic [NUM_CORES -1 : 0] core_leds;
    genvar i;
    generate
        for (i = 0; i < NUM_CORES; i++) begin : core_array

            CoreInstructionInterface core_inst (
                .clk(clk),
                .rst(rst),

                .decode_pipe_divide(decode_pipe_divide),
                .decode_pipe_load(decode_pipe_load),
                .decode_pipe_store(decode_pipe_store),
                .decode_pipe_mul(decode_pipe_mul),
                .decode_pipe_alu(decode_pipe_alu),
                .decode_pipe_aluop({decode_pipe_use_imm, decode_pipe_aluop}),
                .ctx(cur_ctx),
                .decode_pipe_imm(decode_pipe_imm),
                .src1_id(sr1),
                .src2_id(sr2),
                .decode_pipe_dr(decode_pipe_dr),
                .decode_pipe_shift_amt(decode_pipe_shift_amt),
                .instructions_to_skip(instructions_to_skip),
                .decode_pipe_nzp(decode_pipe_nzp),
                .decode_pipe_shared(decode_pipe_shared),
                .decode_pipe_byte_enable(decode_pipe_byte_enable),

                .div_busy(div_busy[i]),
                .load_busy(load_busy[i]),
                .store_busy(store_busy[i]),
                .waiting_load(load_wait_busy[i]),

                .div_reg0(div_reg0[i]),
                .div_reg1(div_reg1[i]),
                .should_divide(should_divide[i]),
                .div_result(div_result[i]),
                .div_finished(div_finished[i]),

                .store_addr(store_addr[i]),
                .store_value(store_value[i]),
                .store_we(store_we[i]),
                .store_enable(store_enable[i]),
                .store_finished(store_finished[i]),

                .load_addr(load_addr[i]),
                .load_finished(load_finished[i]),
                .load_value(load_value[i]),
                .should_load(should_load[i]),
                .finished_load_id(load_finished_id[i]),
                .load_command_id(load_command_id[i]),
                .load_acknowledged(load_acknowledged[i]),

                .sr1_sel(sr1_sel[i]), 
                .sr2_sel(sr2_sel[i]),
                .sr1_in(sr1_value[i]), 
                .sr2_in(sr2_value[i]), 
                .dr_sel(dr_sel[i]), 
                .dr(dr_value[i]), 
                .dr_en(dr_en[i]),
                .ctx_instruction_skip(coresWaiting[i]),
                .freeze_alu(freeze_alu[i]),
                .dont_dispatch_mul(dont_dispatch_mul[i]),
                .mul_output_ctx(mul_output_ctx[i]),
                .mul_write(mul_write[i]),
                .alu_waiting(alu_waiting[i]),
                .div_ctx(div_ctx_write[i]),
                .div_write(div_write[i]),
                .waiting_store(waiting_store[i]),
                .led(core_leds[i]),
                .decode_pipe_sr1(decode_pipe_sr1),
                .decode_pipe_sr2(decode_pipe_sr2),
                .live_divide(live_divide[i])
            );
        end
    endgenerate
    always_ff @(posedge clk) begin
        decode_pipe_sr1 <= sr1_sel[0];
        decode_pipe_sr2 <= sr2_sel[0];
    end
twoReadOneWriteRegFile_0 a(.clk,.rst,.sr1_sel(sr1_sel[0]),.sr2_sel(sr2_sel[0]),
                          .sr1(sr1_value[0]),.sr2(sr2_value[0]),.dr_sel(dr_sel[0]),.dr(dr_value[0]),.dr_en(dr_en[0]));

twoReadOneWriteRegFile_1 b(.clk,.rst,.sr1_sel(sr1_sel[1]),.sr2_sel(sr2_sel[1]),
                          .sr1(sr1_value[1]),.sr2(sr2_value[1]),.dr_sel(dr_sel[1]),.dr(dr_value[1]),.dr_en(dr_en[1]));

twoReadOneWriteRegFile_2 c(.clk,.rst,.sr1_sel(sr1_sel[2]),.sr2_sel(sr2_sel[2]),
                          .sr1(sr1_value[2]),.sr2(sr2_value[2]),.dr_sel(dr_sel[2]),.dr(dr_value[2]),.dr_en(dr_en[2]));

twoReadOneWriteRegFile_3 d(.clk,.rst,.sr1_sel(sr1_sel[3]),.sr2_sel(sr2_sel[3]),
                          .sr1(sr1_value[3]),.sr2(sr2_value[3]),.dr_sel(dr_sel[3]),.dr(dr_value[3]),.dr_en(dr_en[3]));

twoReadOneWriteRegFile_4 e(.clk,.rst,.sr1_sel(sr1_sel[4]),.sr2_sel(sr2_sel[4]),
                          .sr1(sr1_value[4]),.sr2(sr2_value[4]),.dr_sel(dr_sel[4]),.dr(dr_value[4]),.dr_en(dr_en[4]));

twoReadOneWriteRegFile_5 f(.clk,.rst,.sr1_sel(sr1_sel[5]),.sr2_sel(sr2_sel[5]),
                          .sr1(sr1_value[5]),.sr2(sr2_value[5]),.dr_sel(dr_sel[5]),.dr(dr_value[5]),.dr_en(dr_en[5]));

twoReadOneWriteRegFile_6 g(.clk,.rst,.sr1_sel(sr1_sel[6]),.sr2_sel(sr2_sel[6]),
                          .sr1(sr1_value[6]),.sr2(sr2_value[6]),.dr_sel(dr_sel[6]),.dr(dr_value[6]),.dr_en(dr_en[6]));

twoReadOneWriteRegFile_7 h(.clk,.rst,.sr1_sel(sr1_sel[7]),.sr2_sel(sr2_sel[7]),
                          .sr1(sr1_value[7]),.sr2(sr2_value[7]),.dr_sel(dr_sel[7]),.dr(dr_value[7]),.dr_en(dr_en[7]));

twoReadOneWriteRegFile_8 ai(.clk,.rst,.sr1_sel(sr1_sel[8]),.sr2_sel(sr2_sel[8]),
                           .sr1(sr1_value[8]),.sr2(sr2_value[8]),.dr_sel(dr_sel[8]),.dr(dr_value[8]),.dr_en(dr_en[8]));

twoReadOneWriteRegFile_9 j(.clk,.rst,.sr1_sel(sr1_sel[9]),.sr2_sel(sr2_sel[9]),
                          .sr1(sr1_value[9]),.sr2(sr2_value[9]),.dr_sel(dr_sel[9]),.dr(dr_value[9]),.dr_en(dr_en[9]));

twoReadOneWriteRegFile_10 k(.clk,.rst,.sr1_sel(sr1_sel[10]),.sr2_sel(sr2_sel[10]),
                           .sr1(sr1_value[10]),.sr2(sr2_value[10]),.dr_sel(dr_sel[10]),.dr(dr_value[10]),.dr_en(dr_en[10]));

twoReadOneWriteRegFile_11 l(.clk,.rst,.sr1_sel(sr1_sel[11]),.sr2_sel(sr2_sel[11]),
                           .sr1(sr1_value[11]),.sr2(sr2_value[11]),.dr_sel(dr_sel[11]),.dr(dr_value[11]),.dr_en(dr_en[11]));

twoReadOneWriteRegFile_12 m(.clk,.rst,.sr1_sel(sr1_sel[12]),.sr2_sel(sr2_sel[12]),
                           .sr1(sr1_value[12]),.sr2(sr2_value[12]),.dr_sel(dr_sel[12]),.dr(dr_value[12]),.dr_en(dr_en[12]));

twoReadOneWriteRegFile_13 n(.clk,.rst,.sr1_sel(sr1_sel[13]),.sr2_sel(sr2_sel[13]),
                           .sr1(sr1_value[13]),.sr2(sr2_value[13]),.dr_sel(dr_sel[13]),.dr(dr_value[13]),.dr_en(dr_en[13]));

twoReadOneWriteRegFile_14 o(.clk,.rst,.sr1_sel(sr1_sel[14]),.sr2_sel(sr2_sel[14]),
                           .sr1(sr1_value[14]),.sr2(sr2_value[14]),.dr_sel(dr_sel[14]),.dr(dr_value[14]),.dr_en(dr_en[14]));

twoReadOneWriteRegFile_15 p(.clk,.rst,.sr1_sel(sr1_sel[15]),.sr2_sel(sr2_sel[15]),
                           .sr1(sr1_value[15]),.sr2(sr2_value[15]),.dr_sel(dr_sel[15]),.dr(dr_value[15]),.dr_en(dr_en[15]));

twoReadOneWriteRegFile_16 q(.clk,.rst,.sr1_sel(sr1_sel[16]),.sr2_sel(sr2_sel[16]),
                           .sr1(sr1_value[16]),.sr2(sr2_value[16]),.dr_sel(dr_sel[16]),.dr(dr_value[16]),.dr_en(dr_en[16]));
twoReadOneWriteRegFile_17 r(.clk,.rst,.sr1_sel(sr1_sel[17]),.sr2_sel(sr2_sel[17]),
                           .sr1(sr1_value[17]),.sr2(sr2_value[17]),.dr_sel(dr_sel[17]),.dr(dr_value[17]),.dr_en(dr_en[17]));
twoReadOneWriteRegFile_18 s(.clk,.rst,.sr1_sel(sr1_sel[18]),.sr2_sel(sr2_sel[18]),
                           .sr1(sr1_value[18]),.sr2(sr2_value[18]),.dr_sel(dr_sel[18]),.dr(dr_value[18]),.dr_en(dr_en[18]));
twoReadOneWriteRegFile_19 t(.clk,.rst,.sr1_sel(sr1_sel[19]),.sr2_sel(sr2_sel[19]),
                           .sr1(sr1_value[19]),.sr2(sr2_value[19]),.dr_sel(dr_sel[19]),.dr(dr_value[19]),.dr_en(dr_en[19]));
    logic [9:0] readAddress;
    assign readAddress = (skip_ctx) ? ctx_pc[next_ctx] : ctx_pc[cur_ctx] + 1;
    instructionBuf ibuf_inst (
        .clka   (clk),
        .ena    (new_inst_valid),
        .wea    (1'b1),
        .addra  (insert_tail),
        .dina   (new_inst),

        .clkb   (clk),
        .enb    (1'b1),
        .addrb  (readAddress),
        .doutb  (instruction)
    );
    integer xxx;
    logic [NUM_CORES - 1:0] ooga;
    always_comb begin
        for(xxx = 0; xxx < NUM_CORES; xxx++)
            ooga[xxx] = store_we[xxx] != 4'b1111;
    end
    assign led = core_leds[19:4];
    iuop iuop_inst (
        .clka   (clk),
        .ena    (new_inst_valid),
        .wea    (1'b1),
        .addra  (insert_tail),
        .dina   ({12'd0, new_inst[31:28] == 4'b0011, new_inst[31:28] == 4'b0100, new_inst[31:29] == 3'b100, new_inst[31:29] == 3'b101}),//div, load, store

        .clkb   (clk),
        .enb    (1'b1),
        .addrb  (ctx_pc[next_ctx_plus_one]),
        .doutb  (ahead_output)
    );

endmodule
