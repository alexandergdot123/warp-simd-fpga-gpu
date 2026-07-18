module twoReadOneWriteRegFile_0 (
    input  logic clk, input logic rst, input logic [7:0] sr1_sel, input logic [7:0] sr2_sel,
    output logic [31:0] sr1, output logic [31:0] sr2, input logic [7:0] dr_sel, input logic [31:0] dr, input logic dr_en);
    bram_regfile_inst_0 u_regfile_read2  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr1_sel), .doutb(sr1));
    bram_regfile_inst_0 u_regfile_read1  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr2_sel), .doutb(sr2));
endmodule


module twoReadOneWriteRegFile_1 (
    input  logic clk, input logic rst, input logic [7:0] sr1_sel, input logic [7:0] sr2_sel,
    output logic [31:0] sr1, output logic [31:0] sr2, input logic [7:0] dr_sel, input logic [31:0] dr, input logic dr_en);
    bram_regfile_inst_1 u_regfile_read2  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr1_sel), .doutb(sr1));
    bram_regfile_inst_1 u_regfile_read1  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr2_sel), .doutb(sr2));
endmodule


module twoReadOneWriteRegFile_2 (
    input  logic clk, input logic rst, input logic [7:0] sr1_sel, input logic [7:0] sr2_sel,
    output logic [31:0] sr1, output logic [31:0] sr2, input logic [7:0] dr_sel, input logic [31:0] dr, input logic dr_en);
    bram_regfile_inst_2 u_regfile_read2  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr1_sel), .doutb(sr1));
    bram_regfile_inst_2 u_regfile_read1  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr2_sel), .doutb(sr2));
endmodule


module twoReadOneWriteRegFile_3 (
    input  logic clk, input logic rst, input logic [7:0] sr1_sel, input logic [7:0] sr2_sel,
    output logic [31:0] sr1, output logic [31:0] sr2, input logic [7:0] dr_sel, input logic [31:0] dr, input logic dr_en);
    bram_regfile_inst_3 u_regfile_read2  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr1_sel), .doutb(sr1));
    bram_regfile_inst_3 u_regfile_read1  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr2_sel), .doutb(sr2));
endmodule

module twoReadOneWriteRegFile_4 (
    input  logic clk, input logic rst, input logic [7:0] sr1_sel, input logic [7:0] sr2_sel,
    output logic [31:0] sr1, output logic [31:0] sr2, input logic [7:0] dr_sel, input logic [31:0] dr, input logic dr_en);
    bram_regfile_inst_4 u_regfile_read2  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr1_sel), .doutb(sr1));
    bram_regfile_inst_4 u_regfile_read1  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr2_sel), .doutb(sr2));
endmodule


module twoReadOneWriteRegFile_5 (
    input  logic clk, input logic rst, input logic [7:0] sr1_sel, input logic [7:0] sr2_sel,
    output logic [31:0] sr1, output logic [31:0] sr2, input logic [7:0] dr_sel, input logic [31:0] dr, input logic dr_en);
    bram_regfile_inst_5 u_regfile_read2  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr1_sel), .doutb(sr1));
    bram_regfile_inst_5 u_regfile_read1  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr2_sel), .doutb(sr2));
endmodule


module twoReadOneWriteRegFile_6 (
    input  logic clk, input logic rst, input logic [7:0] sr1_sel, input logic [7:0] sr2_sel,
    output logic [31:0] sr1, output logic [31:0] sr2, input logic [7:0] dr_sel, input logic [31:0] dr, input logic dr_en);
    bram_regfile_inst_6 u_regfile_read2  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr1_sel), .doutb(sr1));
    bram_regfile_inst_6 u_regfile_read1  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr2_sel), .doutb(sr2));
endmodule


module twoReadOneWriteRegFile_7 (
    input  logic clk, input logic rst, input logic [7:0] sr1_sel, input logic [7:0] sr2_sel,
    output logic [31:0] sr1, output logic [31:0] sr2, input logic [7:0] dr_sel, input logic [31:0] dr, input logic dr_en);
    bram_regfile_inst_7 u_regfile_read2  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr1_sel), .doutb(sr1));
    bram_regfile_inst_7 u_regfile_read1  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr2_sel), .doutb(sr2));
endmodule


module twoReadOneWriteRegFile_8 (
    input  logic clk, input logic rst, input logic [7:0] sr1_sel, input logic [7:0] sr2_sel,
    output logic [31:0] sr1, output logic [31:0] sr2, input logic [7:0] dr_sel, input logic [31:0] dr, input logic dr_en);
    bram_regfile_inst_8 u_regfile_read2  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr1_sel), .doutb(sr1));
    bram_regfile_inst_8 u_regfile_read1  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr2_sel), .doutb(sr2));
endmodule

module twoReadOneWriteRegFile_9 (
    input  logic clk, input logic rst, input logic [7:0] sr1_sel, input logic [7:0] sr2_sel,
    output logic [31:0] sr1, output logic [31:0] sr2, input logic [7:0] dr_sel, input logic [31:0] dr, input logic dr_en);
    bram_regfile_inst_9 u_regfile_read2  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr1_sel), .doutb(sr1));
    bram_regfile_inst_9 u_regfile_read1  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr2_sel), .doutb(sr2));
endmodule

module twoReadOneWriteRegFile_10 (
    input  logic clk, input logic rst, input logic [7:0] sr1_sel, input logic [7:0] sr2_sel,
    output logic [31:0] sr1, output logic [31:0] sr2, input logic [7:0] dr_sel, input logic [31:0] dr, input logic dr_en);
    bram_regfile_inst_10 u_regfile_read2  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr1_sel), .doutb(sr1));
    bram_regfile_inst_10 u_regfile_read1  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr2_sel), .doutb(sr2));
endmodule


module twoReadOneWriteRegFile_11 (
    input  logic clk, input logic rst, input logic [7:0] sr1_sel, input logic [7:0] sr2_sel,
    output logic [31:0] sr1, output logic [31:0] sr2, input logic [7:0] dr_sel, input logic [31:0] dr, input logic dr_en);
    bram_regfile_inst_11 u_regfile_read2  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr1_sel), .doutb(sr1));
    bram_regfile_inst_11 u_regfile_read1  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr2_sel), .doutb(sr2));
endmodule


module twoReadOneWriteRegFile_12 (
    input  logic clk, input logic rst, input logic [7:0] sr1_sel, input logic [7:0] sr2_sel,
    output logic [31:0] sr1, output logic [31:0] sr2, input logic [7:0] dr_sel, input logic [31:0] dr, input logic dr_en);
    bram_regfile_inst_12 u_regfile_read2  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr1_sel), .doutb(sr1));
    bram_regfile_inst_12 u_regfile_read1  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr2_sel), .doutb(sr2));
endmodule


module twoReadOneWriteRegFile_13 (
    input  logic clk, input logic rst, input logic [7:0] sr1_sel, input logic [7:0] sr2_sel,
    output logic [31:0] sr1, output logic [31:0] sr2, input logic [7:0] dr_sel, input logic [31:0] dr, input logic dr_en);
    bram_regfile_inst_13 u_regfile_read2  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr1_sel), .doutb(sr1));
    bram_regfile_inst_13 u_regfile_read1  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr2_sel), .doutb(sr2));
endmodule

module twoReadOneWriteRegFile_14 (
    input  logic clk, input logic rst, input logic [7:0] sr1_sel, input logic [7:0] sr2_sel,
    output logic [31:0] sr1, output logic [31:0] sr2, input logic [7:0] dr_sel, input logic [31:0] dr, input logic dr_en);
    bram_regfile_inst_14 u_regfile_read2  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr1_sel), .doutb(sr1));
    bram_regfile_inst_14 u_regfile_read1  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr2_sel), .doutb(sr2));
endmodule


module twoReadOneWriteRegFile_15 (
    input  logic clk, input logic rst, input logic [7:0] sr1_sel, input logic [7:0] sr2_sel,
    output logic [31:0] sr1, output logic [31:0] sr2, input logic [7:0] dr_sel, input logic [31:0] dr, input logic dr_en);
    bram_regfile_inst_15 u_regfile_read2  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr1_sel), .doutb(sr1));
    bram_regfile_inst_15 u_regfile_read1  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr2_sel), .doutb(sr2));
endmodule

module twoReadOneWriteRegFile_16 (
    input  logic clk, input logic rst, input logic [7:0] sr1_sel, input logic [7:0] sr2_sel,
    output logic [31:0] sr1, output logic [31:0] sr2, input logic [7:0] dr_sel, input logic [31:0] dr, input logic dr_en);
    bram_regfile_inst_16 u_regfile_read2  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr1_sel), .doutb(sr1));
    bram_regfile_inst_16 u_regfile_read1  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr2_sel), .doutb(sr2));
endmodule

module twoReadOneWriteRegFile_17 (
    input  logic clk, input logic rst, input logic [7:0] sr1_sel, input logic [7:0] sr2_sel,
    output logic [31:0] sr1, output logic [31:0] sr2, input logic [7:0] dr_sel, input logic [31:0] dr, input logic dr_en);
    bram_regfile_inst_17 u_regfile_read2  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr1_sel), .doutb(sr1));
    bram_regfile_inst_17 u_regfile_read1  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr2_sel), .doutb(sr2));
endmodule

module twoReadOneWriteRegFile_18 (
    input  logic clk, input logic rst, input logic [7:0] sr1_sel, input logic [7:0] sr2_sel,
    output logic [31:0] sr1, output logic [31:0] sr2, input logic [7:0] dr_sel, input logic [31:0] dr, input logic dr_en);
    bram_regfile_inst_18 u_regfile_read2  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr1_sel), .doutb(sr1));
    bram_regfile_inst_18 u_regfile_read1  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr2_sel), .doutb(sr2));
endmodule

module twoReadOneWriteRegFile_19 (
    input  logic clk, input logic rst, input logic [7:0] sr1_sel, input logic [7:0] sr2_sel,
    output logic [31:0] sr1, output logic [31:0] sr2, input logic [7:0] dr_sel, input logic [31:0] dr, input logic dr_en);
    bram_regfile_inst_19 u_regfile_read2  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr1_sel), .doutb(sr1));
    bram_regfile_inst_19 u_regfile_read1  (
        .clka(clk), .ena(dr_en && ~(dr_sel[3:0]==4'hF)), .wea(dr_en && ~(dr_sel[3:0]==4'hF)), 
        .addra(dr_sel), .dina(dr), .clkb(clk), .enb(1'b1), .addrb(sr2_sel), .doutb(sr2));
endmodule