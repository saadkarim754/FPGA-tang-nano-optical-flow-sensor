//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.11.01 Education (64-bit)
//Part Number: GW1NSR-LV4CQN48PC6/I5
//Device: GW1NSR-4C
//Created Time: Sun Apr 12 11:43:27 2026

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

	Gowin_EMPU_Top your_instance_name(
		.sys_clk(sys_clk), //input sys_clk
		.gpio(gpio), //inout [15:0] gpio
		.uart0_rxd(uart0_rxd), //input uart0_rxd
		.uart0_txd(uart0_txd), //output uart0_txd
		.uart1_rxd(uart1_rxd), //input uart1_rxd
		.uart1_txd(uart1_txd), //output uart1_txd
		.scl(scl), //inout scl
		.sda(sda), //inout sda
		.master_hclk(master_hclk), //output master_hclk
		.master_hrst(master_hrst), //output master_hrst
		.master_hsel(master_hsel), //output master_hsel
		.master_haddr(master_haddr), //output [31:0] master_haddr
		.master_htrans(master_htrans), //output [1:0] master_htrans
		.master_hwrite(master_hwrite), //output master_hwrite
		.master_hsize(master_hsize), //output [2:0] master_hsize
		.master_hburst(master_hburst), //output [2:0] master_hburst
		.master_hprot(master_hprot), //output [3:0] master_hprot
		.master_hmemattr(master_hmemattr), //output [1:0] master_hmemattr
		.master_hexreq(master_hexreq), //output master_hexreq
		.master_hmaster(master_hmaster), //output [3:0] master_hmaster
		.master_hwdata(master_hwdata), //output [31:0] master_hwdata
		.master_hmastlock(master_hmastlock), //output master_hmastlock
		.master_hreadymux(master_hreadymux), //output master_hreadymux
		.master_hauser(master_hauser), //output master_hauser
		.master_hwuser(master_hwuser), //output [3:0] master_hwuser
		.master_hrdata(master_hrdata), //input [31:0] master_hrdata
		.master_hreadyout(master_hreadyout), //input master_hreadyout
		.master_hresp(master_hresp), //input master_hresp
		.master_hexresp(master_hexresp), //input master_hexresp
		.master_hruser(master_hruser), //input [2:0] master_hruser
		.slave_hsel(slave_hsel), //input slave_hsel
		.slave_haddr(slave_haddr), //input [31:0] slave_haddr
		.slave_htrans(slave_htrans), //input [1:0] slave_htrans
		.slave_hwrite(slave_hwrite), //input slave_hwrite
		.slave_hsize(slave_hsize), //input [2:0] slave_hsize
		.slave_hburst(slave_hburst), //input [2:0] slave_hburst
		.slave_hprot(slave_hprot), //input [3:0] slave_hprot
		.slave_hmemattr(slave_hmemattr), //input [1:0] slave_hmemattr
		.slave_hexreq(slave_hexreq), //input slave_hexreq
		.slave_hmaster(slave_hmaster), //input [3:0] slave_hmaster
		.slave_hwdata(slave_hwdata), //input [31:0] slave_hwdata
		.slave_hmastlock(slave_hmastlock), //input slave_hmastlock
		.slave_hauser(slave_hauser), //input slave_hauser
		.slave_hwuser(slave_hwuser), //input [3:0] slave_hwuser
		.slave_hrdata(slave_hrdata), //output [31:0] slave_hrdata
		.slave_hready(slave_hready), //output slave_hready
		.slave_hresp(slave_hresp), //output slave_hresp
		.slave_hexresp(slave_hexresp), //output slave_hexresp
		.slave_hruser(slave_hruser), //output [2:0] slave_hruser
		.user_int_0(user_int_0), //input user_int_0
		.user_int_1(user_int_1), //input user_int_1
		.reset_n(reset_n) //input reset_n
	);

//--------Copy end-------------------
