
`timescale 1 ns / 1 ps

	module warp_gpu_v1_0 #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 5
	)
	(
		// Users to add ports here

		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready,
		
        input  wire [31:0]                   warp_gpu_draw_concatenated,
            // ----------------------------
        output wire [127:0]                  warp_gpu_cache_data_write,
        output wire [26:0]                   warp_gpu_cache_address,
        input  wire [127:0]                  warp_gpu_cache_data_read,
        output wire                          warp_gpu_cache_enable_global,
        output wire                          warp_gpu_cache_enable_global_write,
        output wire [15:0]                   warp_gpu_cache_write_bytes,
        input  wire                          warp_gpu_cache_finished_read,
        input wire                           mem_controller_ready_for_instruction,
        input wire clk_slow,
        input wire clk_slow_locked,
        output wire [15:0] led
        

    );
    // Instantiation of Axi Bus Interface S00_AXI
    warp_gpu_v1_0_S00_AXI #(
        .C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
    ) warp_gpu_v1_0_S00_AXI_inst (
        .s_axi_aclk(s00_axi_aclk),
        .s_axi_aresetn(s00_axi_aresetn),
    
        .s_axi_awaddr(s00_axi_awaddr),
        .s_axi_awprot(s00_axi_awprot),
        .s_axi_awvalid(s00_axi_awvalid),
        .s_axi_awready(s00_axi_awready),
    
        .s_axi_wdata(s00_axi_wdata),
        .s_axi_wstrb(s00_axi_wstrb),
        .s_axi_wvalid(s00_axi_wvalid),
        .s_axi_wready(s00_axi_wready),
    
        .s_axi_bresp(s00_axi_bresp),
        .s_axi_bvalid(s00_axi_bvalid),
        .s_axi_bready(s00_axi_bready),
    
        .s_axi_araddr(s00_axi_araddr),
        .s_axi_arprot(s00_axi_arprot),
        .s_axi_arvalid(s00_axi_arvalid),
        .s_axi_arready(s00_axi_arready),
    
        .s_axi_rdata(s00_axi_rdata),
        .s_axi_rresp(s00_axi_rresp),
        .s_axi_rvalid(s00_axi_rvalid),
        .s_axi_rready(s00_axi_rready),
    
        .warp_gpu_draw_concatenated(warp_gpu_draw_concatenated),
        .warp_gpu_cache_data_write(warp_gpu_cache_data_write),
        .warp_gpu_cache_address(warp_gpu_cache_address),
        .warp_gpu_cache_data_read(warp_gpu_cache_data_read),
        .warp_gpu_cache_enable_global(warp_gpu_cache_enable_global),
        .warp_gpu_cache_enable_global_write(warp_gpu_cache_enable_global_write),
        .warp_gpu_cache_write_bytes(warp_gpu_cache_write_bytes),
        .warp_gpu_cache_finished_read(warp_gpu_cache_finished_read),
        .mem_controller_ready_for_instruction(mem_controller_ready_for_instruction),
        
        .clk_slow(clk_slow),
        .clk_slow_locked(clk_slow_locked),
        .led(led)
    );


	// Add user logic here

	// User logic ends

	endmodule
