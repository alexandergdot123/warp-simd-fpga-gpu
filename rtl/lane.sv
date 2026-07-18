module CoreInstructionInterface (
    input  logic         clk,
    input  logic         rst,

    // Front-end decoded instruction signals
    input  logic         decode_pipe_divide,
    input  logic         decode_pipe_load,
    input  logic         decode_pipe_store,
    input  logic         decode_pipe_mul,
    input  logic         decode_pipe_alu,
    input  logic [3:0]   decode_pipe_aluop,
    input  logic [3:0]   ctx,
    input  logic [31:0]  decode_pipe_imm,
    input  logic [3:0]   src1_id,
    input  logic [3:0]   src2_id,
    input  logic [3:0]   decode_pipe_dr,
    input  logic [2:0]   decode_pipe_shift_amt,
    input  logic [7:0]   instructions_to_skip,
    input  logic [2:0]   decode_pipe_nzp,
    input  logic         decode_pipe_shared,
    input  logic [3:0]   decode_pipe_byte_enable,
    input logic [7:0] decode_pipe_sr1,
    input logic [7:0] decode_pipe_sr2,


    output logic [3:0]   mul_output_ctx,
    output logic         div_busy,
    output logic         load_busy,
    output logic         store_busy,


    // Back-end divide interface
    output logic [31:0]  div_reg0,
    output logic [31:0]  div_reg1,
    output logic         should_divide,
    input  logic [31:0]  div_result,
    input  logic         div_finished,

    // Back-end store interface
    output logic [31:0]  store_addr,
    output logic [31:0]  store_value,
    output logic [3:0]   store_we,
    output logic         store_enable,
    input  logic         store_finished,

    // Back-end load interface
    output logic [31:0]  load_addr,
    input  logic         load_finished,
    input  logic         load_acknowledged,
    input  logic [31:0]  load_value,
    output logic         should_load,
    input logic [7:0] finished_load_id,
    output logic [7:0] load_command_id,
    
    
    output logic [7:0] sr1_sel, 
    output logic [7:0] sr2_sel,
    input logic [31:0] sr1_in, 
    input logic [31:0] sr2_in, 
    output logic [7:0] dr_sel, 
    output logic [31:0] dr, 
    output logic dr_en,
    output logic [15:0][6:0] ctx_instruction_skip,
    output logic freeze_alu,
    output logic dont_dispatch_mul,
    output logic waiting_load,
    output logic waiting_store,
    output logic alu_waiting,
    output logic mul_write,
    output logic div_write,
    output logic live_divide,
    output logic [3:0] div_ctx,
    output logic led
);
    logic [7:0] div_id, alu_id, load_id, waiting_load_id, mul_output_id;
    logic [31:0] div_hold_result, alu_holding_result, waiting_load_address;
    logic [31:0] alu_out, mul_out;
    logic [3:0] decode_pipe_ctx;
    assign sr1_sel = {ctx, src1_id};
    assign sr2_sel = {ctx, src2_id};
    assign div_ctx = dr_sel[7:4];
    logic [2:0] nzp;
    logic freeze_mul_output, freeze_div;
    logic div_waiting;
    assign div_write = (div_waiting || div_finished) && ~freeze_div;
    logic [31:0] sr1, sr2;
    logic [1:0] last_alu;
    logic [31:0] store_address_waiting, store_value_waiting;
    logic [3:0] store_we_waiting;
    
    logic holding_alu, freeze_mul_input;
    logic mul_input_busy, mul_output_busy;

    assign freeze_mul_input = freeze_mul_output && mul_input_busy;
    assign dr_en = (decode_pipe_alu && decode_pipe_nzp == '0 && ctx_instruction_skip[decode_pipe_ctx] == '0) || load_finished || div_finished || div_waiting || mul_output_busy || holding_alu;
    assign dont_dispatch_mul = decode_pipe_mul || mul_output_busy || mul_input_busy;;
    assign alu_waiting = holding_alu;
    logic [31:0] destination_register_value_anded;
    assign destination_register_value_anded = dr & {31{dr_en}};
    always_comb begin
        freeze_div = '0;
        freeze_mul_output = '0;
        freeze_alu = '0;
        if(((decode_pipe_alu && ctx_instruction_skip[decode_pipe_ctx] == '0 && decode_pipe_nzp == '0) || holding_alu) && load_finished) begin
            freeze_alu = '1;
        end
        if (decode_pipe_alu && (div_finished || div_waiting) && ctx_instruction_skip[decode_pipe_ctx] == '0 && decode_pipe_nzp == '0) begin
            freeze_div = '1;
        end
        if (decode_pipe_alu && mul_output_busy && ctx_instruction_skip[decode_pipe_ctx] == '0 && decode_pipe_nzp == '0) begin
            freeze_mul_output = '1;
        end
        if ((div_finished || div_waiting) && load_finished) begin
            freeze_div = '1;
        end
        if (mul_output_busy && load_finished) begin
            freeze_mul_output = '1;
        end
        if (mul_output_busy && (div_finished || div_waiting)) begin
            if (decode_pipe_divide) 
                freeze_mul_output = '1;
            else
                freeze_div = '1;
        end
        if (mul_output_busy && holding_alu)
            freeze_mul_output = '1;
        if ((div_finished || div_waiting) && holding_alu)
            freeze_div = '1;
    end

    assign dr = ({32{holding_alu && ~freeze_alu}} & alu_holding_result) | 
        ({32{decode_pipe_alu && ctx_instruction_skip[decode_pipe_ctx] == '0 && decode_pipe_nzp == '0 && ~freeze_alu}} & alu_out) | 
        ({32{(div_finished || div_waiting) & ~freeze_div}} & (div_waiting ? div_hold_result : div_result)) | 
        ({32{mul_output_busy & ~freeze_mul_output}} & mul_out) | ({32{load_finished}} & load_value);
    assign dr_sel = ({8{decode_pipe_alu && ctx_instruction_skip[decode_pipe_ctx] == '0 && decode_pipe_nzp == '0 && ~freeze_alu}} & {decode_pipe_ctx, decode_pipe_dr}) | 
            ({8{(div_finished || div_waiting) & ~freeze_div}} & div_id) | 
            ({8{mul_output_busy & ~freeze_mul_output}} & mul_output_id) | 
            ({8{load_finished}} & finished_load_id) | 
            ({8{holding_alu & ~freeze_alu}} & alu_id);
    CombinationalALU alu_inst(
        .sr1(sr1),
        .sr2(sr2),
        .imm(decode_pipe_imm),
        .alu_op(decode_pipe_aluop),
        .shift_amt_code(decode_pipe_shift_amt),
        .result(alu_out),
        .flags(nzp) 
    );
    always_ff @(posedge clk) begin
        decode_pipe_ctx <= ctx;
        
        
        if(rst) begin
            ctx_instruction_skip <= '0;            
        end
        else begin
            if(ctx_instruction_skip[decode_pipe_ctx] == '0 && (decode_pipe_nzp & nzp) != '0 && decode_pipe_alu)
                ctx_instruction_skip[decode_pipe_ctx] <= instructions_to_skip[6:0];

            if (ctx_instruction_skip[decode_pipe_ctx] != '0 && (decode_pipe_divide || decode_pipe_store || decode_pipe_mul || decode_pipe_alu || decode_pipe_load))
                ctx_instruction_skip[decode_pipe_ctx] <= ctx_instruction_skip[decode_pipe_ctx] - 1;
        end

        if(rst) begin
            div_waiting <= '0;
        end
        else begin 
            div_waiting <= freeze_div;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            store_enable <= '0;
            should_load <= '0;
            should_divide <= '0;
            waiting_load <= '0;
            waiting_store <= '0;
            live_divide <= '0;
        end
        else begin

            if(ctx_instruction_skip[decode_pipe_ctx] == '0 && decode_pipe_divide) begin
                div_reg0 <= sr1;
                div_reg1 <= (decode_pipe_aluop[3]) ? decode_pipe_imm : sr2;
                should_divide <= '1;
                div_id <= {decode_pipe_ctx, decode_pipe_dr};
                live_divide <= '1;
            end
            else if(div_finished) begin
                should_divide <= '0; 
                div_hold_result <= div_result;
                if(div_write)
                    live_divide <= '0;
            end
            else if (div_write)
                live_divide <= '0;
    
       
            if(ctx_instruction_skip[decode_pipe_ctx] == '0 && decode_pipe_load) begin
               waiting_load_address <= {decode_pipe_shared, alu_out[30:0]};
                waiting_load_id <= {decode_pipe_ctx, decode_pipe_dr};
            end

            if(~waiting_load && ctx_instruction_skip[decode_pipe_ctx] == '0 && decode_pipe_load)
                waiting_load <= '1;
            else if(waiting_load && (load_acknowledged || ~should_load) && ~(decode_pipe_load && ctx_instruction_skip[decode_pipe_ctx] == '0)) begin
                waiting_load <= '0;
            end
            
            
            if(load_acknowledged || ~should_load) begin
                load_id <= waiting_load_id;
                load_addr <= waiting_load_address;
            end
    
            if(waiting_load && (load_acknowledged || ~should_load))
                should_load <= '1; 
            else if (load_acknowledged && ~waiting_load)
                should_load <= '0;
                
    
    
            if(ctx_instruction_skip[decode_pipe_ctx] == '0 && decode_pipe_store) begin
                waiting_store <= '1;
                store_address_waiting <= {decode_pipe_shared, alu_out[30:0]};
                store_value_waiting <= sr2;
                store_we_waiting <= decode_pipe_byte_enable;
            end
            else if(~(decode_pipe_store && ctx_instruction_skip[decode_pipe_ctx] == '0) && (~store_enable || store_finished) && waiting_store) begin
                waiting_store <= '0;
            end


            if(store_enable && ~waiting_store && store_finished)
                store_enable <= '0;
            else if (~store_enable && waiting_store)
                store_enable <= '1;


            if(waiting_store && (~store_enable || store_finished)) begin
                store_addr <= store_address_waiting;
                store_value <= store_value_waiting;
                store_we <= store_we_waiting;
            end





        end
    end

    always_comb begin
        div_busy = should_divide && ~div_finished;
        load_command_id = load_id;
        load_busy = should_load;  //This might complicate timing

        store_busy = store_enable;
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            mul_input_busy <= '0;
            mul_output_busy <= '0;
            holding_alu <= '0;
        end
        else begin
            if(~freeze_mul_input)
                mul_input_busy <= ctx_instruction_skip[decode_pipe_ctx] == '0 && decode_pipe_mul;
        
            if(~freeze_mul_output)
                mul_output_busy <= mul_input_busy;
                
                
            holding_alu <= freeze_alu;
        end
        
        if(~freeze_alu || ~holding_alu) begin
            alu_id <= {decode_pipe_ctx, decode_pipe_dr};
            alu_holding_result <= alu_out;
        end
       
    end
    always_ff @(posedge clk) begin
        if(rst)
            led <= '0;
        else if (freeze_alu)
            led <= '1;
        
    end
    always_ff @(posedge clk) begin
        if(rst) 
            last_alu <= '0;
        else begin
            last_alu[0] <= decode_pipe_alu && ctx_instruction_skip[decode_pipe_ctx] == '0 && 
                decode_pipe_nzp == '0 && src1_id[3:0] != 4'b1111 && sr1_sel == {decode_pipe_ctx, decode_pipe_dr};
            last_alu[1] <= decode_pipe_alu && ctx_instruction_skip[decode_pipe_ctx] == '0 && 
                decode_pipe_nzp == '0 && src2_id[3:0] != 4'b1111 && sr2_sel == {decode_pipe_ctx, decode_pipe_dr};
        end
    end
    assign sr1 = (last_alu[0]) ? alu_holding_result : sr1_in;
    assign sr2 = (last_alu[1]) ? alu_holding_result : sr2_in;
//    assign sr1 = sr1_in;
//    assign sr2 = sr2_in;
    multiplier mult_inst(
        .clk(clk),
        .rst(rst),

        .do_multiply(decode_pipe_mul && ctx_instruction_skip[decode_pipe_ctx] == '0),
        .sr1(sr1),
        .sr2(decode_pipe_aluop[3] ? decode_pipe_imm : sr2),
        .dr({decode_pipe_ctx, decode_pipe_dr}),

        .product(mul_out),
        .product_id(mul_output_id),
        .stall_input(freeze_mul_input),
        .stall_output(freeze_mul_output)
    );
    assign mul_write = ~freeze_mul_output && mul_output_busy;
    assign mul_output_ctx = mul_output_id[7:4];
endmodule

module CombinationalALU (
    input  logic [31:0] sr1,
    input  logic [31:0] sr2,
    input  logic [31:0] imm,
    input  logic [3:0]  alu_op,         // bit[3] selects imm vs sr2
    input  logic [2:0]  shift_amt_code, // 0->1, 1->2, 2->4, 3->8, 4->16, 5->24
    output logic [31:0] result,
    output logic [2:0]  flags           // {Zero, Negative, Positive}
);

    logic [31:0] op2, intermediate_result;
    assign op2 = alu_op[3] ? imm : sr2;

    // Precompute shifted versions using concatenations (explicit wiring)
    logic [31:0] shl, shr, sar;

    always_comb begin
        case (shift_amt_code)
            3'd0: begin // shift by 1
                shl = {sr1[30:0], 1'b0};
                shr = {1'b0, sr1[31:1]};
                sar = {sr1[31], sr1[31:1]};
            end
            3'd1: begin // shift by 2
                shl = {sr1[29:0], 2'b0};
                shr = {2'b0, sr1[31:2]};
                sar = {{2{sr1[31]}}, sr1[31:2]};
            end
            3'd2: begin // shift by 4
                shl = {sr1[27:0], 4'b0};
                shr = {4'b0, sr1[31:4]};
                sar = {{4{sr1[31]}}, sr1[31:4]};
            end
            3'd3: begin // shift by 8
                shl = {sr1[23:0], 8'b0};
                shr = {8'b0, sr1[31:8]};
                sar = {{8{sr1[31]}}, sr1[31:8]};
            end
            3'd4: begin // shift by 16
                shl = {sr1[15:0], 16'b0};
                shr = {16'b0, sr1[31:16]};
                sar = {{16{sr1[31]}}, sr1[31:16]};
            end
            3'd5: begin // shift by 24
                shl = {sr1[7:0], 24'b0};
                shr = {24'b0, sr1[31:24]};
                sar = {{24{sr1[31]}}, sr1[31:24]};
            end
            default: begin
                shl = sr1;
                shr = sr1;
                sar = sr1;
            end
        endcase
    end

    // ALU operations
    always_comb begin
        unique case (alu_op[2:0])
            3'b000: intermediate_result = sr1 + op2;   // ADD
            3'b001: intermediate_result = sr1 - op2;   // SUB
            3'b010: intermediate_result = shl;         // SHL
            3'b011: intermediate_result = shr;         // SHR logical
            3'b100: intermediate_result = sar;         // SHR arithmetic
            3'b101: intermediate_result = sr1 & op2;   // AND
            3'b110: intermediate_result = sr1 | op2;   // OR
            3'b111: intermediate_result = sr1 ^ op2;        // NOT
            default: intermediate_result = 32'd0;
        endcase
    end

    // Flags
    always_comb begin
        flags[1] = (intermediate_result == 32'd0);  // Zero
        flags[2] = intermediate_result[31];         // Negative
        flags[0] = ~flags[2] && ~flags[1]; // Positive
        result = (shift_amt_code[2:1] == 2'b11) ? ((shift_amt_code[0]) ? flags[2] || flags[1] : flags[2]) : intermediate_result;
    end


endmodule



module multiplier(
    input logic clk,
    input logic rst,
    input logic [31:0] sr1,
    input logic [31:0] sr2,
    output logic [31:0] product,
    input logic [7:0] dr,
    output logic [7:0] product_id,
    input logic do_multiply,
    input logic stall_input,
    input logic stall_output
);
    logic [31:0] op1, op2;
    logic [7:0] input_id;
    always_ff @(posedge clk) begin


        input_id <= (stall_input) ? input_id : dr;
        op1 <= (stall_input) ? op1 : sr1;
        op2 <= (stall_input) ? op2 : sr2;

        product <= (stall_output) ? product : (op1 * op2);
        product_id <= (stall_output) ? product_id : input_id;
    end
endmodule