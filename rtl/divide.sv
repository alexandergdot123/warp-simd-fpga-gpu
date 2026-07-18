module divisonUnits #(
    parameter NUM_CORES = 16,
    parameter DIVIDERS = 4
)(
    input logic clk,
    input logic rst,

    input logic [NUM_CORES - 1 : 0][31:0] inputA,
    input logic [NUM_CORES - 1 : 0][31:0] inputB,
    output logic [NUM_CORES - 1 : 0][31:0] outputC,
    input logic [NUM_CORES - 1 : 0] enableDivide,
    output logic [NUM_CORES - 1 : 0] coreDivideFinished
);

    logic [NUM_CORES - 1 : 0] visitedCore;
    logic dividerReady;
    logic [$clog2(NUM_CORES) - 1 : 0]masterPtr;
    logic [DIVIDERS - 1 : 0][$clog2(NUM_CORES) - 1 : 0] childPtrs, dividerOutputPtr;

    logic [DIVIDERS - 1 : 0][31:0] dividerInputA, dividerInputB, dividerOutputC;
    logic [DIVIDERS - 1 : 0] startDivide, finishedDivide;
    always_comb begin
        outputC = 'x;
        coreDivideFinished = '0;
        for(integer i = 0; i < DIVIDERS; i++) begin
            childPtrs[i] = (masterPtr + (i * (NUM_CORES/DIVIDERS))) % NUM_CORES;
            dividerInputA[i] = inputA[childPtrs[i]];
            dividerInputB[i] = inputB[childPtrs[i]];
            
            outputC[dividerOutputPtr[i]] = dividerOutputC[i];
            coreDivideFinished[dividerOutputPtr[i]] = finishedDivide[i];
            startDivide[i] = enableDivide[childPtrs[i]] & ~visitedCore[childPtrs[i]] && dividerReady;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            masterPtr <= '0;
            visitedCore <= '0;
        end
        else begin
            if(dividerReady || visitedCore[masterPtr]) 
                masterPtr <= (masterPtr + 1) % NUM_CORES;
                
            for(integer i = 0; i < DIVIDERS; i++) begin
                if(finishedDivide[i])
                    visitedCore[dividerOutputPtr[i]] <= '0;
                else if(~visitedCore[childPtrs[i]] && enableDivide[childPtrs[i]])
                    visitedCore[childPtrs[i]] <= '1;
            end
        end

    end

    genvar i;
    generate
        for(i = 0; i < DIVIDERS; i++) begin

            divider #(
                .NUM_CORES(NUM_CORES)
            ) dividerInst (
                .clk(clk),
                .rst(rst),
    
                .a(dividerInputA[i]),
                .b(dividerInputB[i]),
                .enableDivide(startDivide[i]),
                .inputCorePtr(childPtrs[i]),
                .dividerReady(dividerReady),
    
                .c(dividerOutputC[i]),
                .finishedDivide(finishedDivide[i]),
                .outputCorePtr(dividerOutputPtr[i])
            );
    
        end
    endgenerate
endmodule

module divider #(
    parameter NUM_CORES = 16,
    parameter DEPTH = 64
)(
    input logic clk,
    input logic rst,

    input logic [31:0] a,
    input logic [31:0] b,
    input logic enableDivide,
    output logic dividerReady, 
    input logic [$clog2(NUM_CORES) - 1 : 0] inputCorePtr,

    output logic [31:0] c,
    output logic finishedDivide,
    output logic [$clog2(NUM_CORES) - 1 : 0] outputCorePtr
);
    logic [$clog2(DEPTH) - 1 : 0] head, tail;
    logic dividerOutputReady;
    logic [63:0] dividerOutput;
    logic [15:0] dummyOutput;
    logic divideByZero;
    assign outputCorePtr = dummyOutput[$clog2(NUM_CORES) - 1 : 0];
    logic s_axis_divisor_tready, s_axis_dividend_tready;
    always_ff @(posedge clk) begin
        if(rst) begin
            head <= '0;
            tail <= '0;
            finishedDivide <= '0;
        end
        else begin
            finishedDivide <= dividerOutputReady;

            if(enableDivide)
                tail <= tail + 1;
            
            if(dividerOutputReady)
                head <= head + 1;

        end

        c <= (divideByZero) ? 32'h00000000 : dividerOutput[63:32];

    end
    assign s_axis_divisor_tready = '1;
    assign s_axis_dividend_tready = '1;
    div_gen_1 div_inst (
        .aclk(clk),
        .aresetn(~rst),
        .s_axis_divisor_tvalid(enableDivide),
        .s_axis_divisor_tdata(b),
        .s_axis_dividend_tvalid(enableDivide),
        .s_axis_dividend_tdata(a),
        
//        .s_axis_divisor_tready(s_axis_divisor_tready),
//        .s_axis_dividend_tready(s_axis_dividend_tready),

        .m_axis_dout_tvalid(dividerOutputReady),
        .m_axis_dout_tdata(dividerOutput),
        .m_axis_dout_tuser(divideByZero)
    );
    div_fifo div_fifo_inst (
        .clka   (clk),
        .ena    (enableDivide),
        .wea    (enableDivide),
        .addra  (tail),
        .dina   ({{16-$clog2(NUM_CORES){1'b0}}, inputCorePtr}),

        .clkb   (clk),
        .enb    (dividerOutputReady),
        .addrb  (head),
        .doutb  (dummyOutput)
    );
    assign dividerReady = s_axis_divisor_tready && s_axis_dividend_tready;
endmodule


module divisonUnits2 #(
    parameter NUM_CORES = 16,
    parameter DIVIDERS = 4
)(
    input logic clk,
    input logic rst,

    input logic [NUM_CORES - 1 : 0][31:0] inputA,
    input logic [NUM_CORES - 1 : 0][31:0] inputB,
    output logic [NUM_CORES - 1 : 0][31:0] outputC,
    input logic [NUM_CORES - 1 : 0] enableDivide,
    output logic [NUM_CORES - 1 : 0] coreDivideFinished
);

    logic [$clog2(NUM_CORES) - 1 : 0] masterPtr;

    logic startDivide, dividerOutputReady, switched;

    logic [31:0] a, b, dividerOutput;

    always_ff @(posedge clk) begin
        if(rst) begin
            masterPtr <= '0;
        end
        else begin
            if(~enableDivide[masterPtr] || dividerOutputReady) begin
                masterPtr <= (masterPtr + 1) % NUM_CORES;
                switched <= '1;
            end
            else begin
                masterPtr <= masterPtr;
                switched <= '0;
            end
        end

    end

    integer i;

    always_comb begin
        a = inputA[masterPtr];
        b = inputB[masterPtr];

        startDivide = enableDivide[masterPtr] && switched;

        for(i = 0; i < NUM_CORES; i++) begin
            outputC[i] = dividerOutput;
        end

        coreDivideFinished = '0;
        coreDivideFinished[masterPtr] = dividerOutputReady;

    end

    logic in_ready, s_axis_dividend_tready, s_axis_divisor_tready;
    assign in_ready = s_axis_dividend_tready && s_axis_divisor_tready;
    assign s_axis_divisor_tready = '1;
    assign s_axis_dividend_tready = '1;

    div_gen_0 div_inst (
        .aclk(clk),
        .s_axis_divisor_tvalid(startDivide && in_ready),
//        .s_axis_divisor_tready(s_axis_divisor_tready),
        .s_axis_divisor_tdata(b),
        .s_axis_dividend_tvalid(startDivide&& in_ready),
//        .s_axis_dividend_tready(s_axis_dividend_tready),
        .s_axis_dividend_tdata(a),
        .m_axis_dout_tvalid(dividerOutputReady),
        .m_axis_dout_tdata(dividerOutput),
        .m_axis_dout_tuser(divideByZero)
    );
endmodule

module divisonUnits3 #(
    parameter NUM_CORES = 16,
    parameter DIVIDERS = 4
)(
    input logic clk,
    input logic rst,

    input logic [NUM_CORES - 1 : 0][31:0] inputA,
    input logic [NUM_CORES - 1 : 0][31:0] inputB,
    output logic [NUM_CORES - 1 : 0][31:0] outputC,
    input logic [NUM_CORES - 1 : 0] enableDivide,
    output logic [NUM_CORES - 1 : 0] coreDivideFinished
);
    assign outputC = 'x;
    assign coreDivideFinished = '0;
endmodule