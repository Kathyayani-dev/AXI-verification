# code for axi_xtn.sv

  ...
  class axi_xtn extends uvm_sequence_item;
	`uvm_object_utils(axi_xtn)

	bit ARESETn;

	//Write Address Channel Signals
	rand bit [3:0]AWID;
	rand bit [31:0]AWADDR;
	rand bit [3:0]AWLEN;
	rand bit [2:0]AWSIZE;
	rand bit [1:0]AWBURST;
	bit AWVALID;
	bit AWREADY;

	//Write Data Channel Signals
	rand bit [3:0]WID;
	rand bit [31:0]WDATA[];
	bit [3:0]WSTRB[];
	bit WLAST;
	bit WVALID;
	bit WREADY;

	//Write Response Channel Signals
	rand bit [3:0]BID;
	bit [1:0]BRESP;
	bit BVALID;
	bit BREADY;

	//Read Address Channel Signals
	rand bit [3:0]ARID;
	rand bit [31:0]ARADDR;
	rand bit [3:0]ARLEN;
	rand bit [2:0]ARSIZE;
	rand bit [1:0]ARBURST;
	bit ARVALID;
	bit ARREADY;

	//Read Data Channel Signals
	rand bit [3:0]RID;
	rand bit [31:0]RDATA[];
	rand bit [1:0]RRESP[];
	bit RLAST;
	bit RVALID;
	bit RREADY;

	function new(string name="axi_xtn");
		super.new(name);
	endfunction

	function void do_print(uvm_printer printer);
		super.do_print(printer);

	//Write Address Channel Print Fields
		printer.print_field("###### WRITE ADDRESS SIGNALS ######",null,0,UVM_DEC);
		printer.print_field("AWID",this.AWID,8,UVM_DEC);
		printer.print_field("AWADDR",this.AWADDR,32,UVM_DEC);
		printer.print_field("AWLEN",this.AWLEN,4,UVM_DEC);
		printer.print_field("AWSIZE",this.AWSIZE,3,UVM_DEC);
		printer.print_field("AWBURST",this.AWBURST,2,UVM_DEC);
		printer.print_field("AWVALID",this.AWVALID,1,UVM_DEC);
		printer.print_field("AWREADY",this.AWREADY,1,UVM_DEC);

	//Write Data Channel Print Fields
		printer.print_field("###### WRITE DATA SIGNALS ######",null,0,UVM_DEC);
		printer.print_field("WID",this.WID,8,UVM_DEC);
		foreach(WDATA[i])
		printer.print_field($sformatf("WDATA[%0d]",i),this.WDATA[i],32,UVM_DEC);
		foreach(WSTRB[i])
		printer.print_field($sformatf("WSTRB[%0d]",i),this.WSTRB[i],4,UVM_DEC);
		printer.print_field("WLAST",this.WLAST,1,UVM_DEC);	
		printer.print_field("WVALID",this.WVALID,1,UVM_DEC);
		printer.print_field("WREADY",this.WREADY,1,UVM_DEC);

	//Write Response Channel Print Fields
		printer.print_field("###### WRITE RESPONSE SIGNALS ######",null,0,UVM_DEC);
		printer.print_field("BID",this.BID,8,UVM_DEC);
		printer.print_field("BRESP",this.BRESP,2,UVM_DEC);
		printer.print_field("BVALID",this.BVALID,1,UVM_DEC);
		printer.print_field("BREADY",this.BREADY,1,UVM_DEC);
	
	//Read Address Channel Print Fields
		printer.print_field("###### READ ADDRESS SIGNALS ######",null,0,UVM_DEC);
		printer.print_field("ARID",this.ARID,8,UVM_DEC);
		printer.print_field("ARADDR",this.ARADDR,32,UVM_DEC);
		printer.print_field("ARLEN",this.ARLEN,8,UVM_DEC);
		printer.print_field("ARSIZE",this.ARSIZE,3,UVM_DEC);
		printer.print_field("ARBURST",this,ARBURST,2,UVM_DEC);
		printer.print_field("ARVALID",this.ARVALID,1,UVM_DEC);
		printer.print_field("ARREADY",this.ARREADY,1,UVM_DEC);

	//Read Data Channel Print Fields
		printer.print_field("###### READ DATA SIGNALS ######",null,0,UVM_DEC);
		printer.print_field("RID",this.RID,8,UVM_DEC);
		foreach(RDATA[i])
		printer.print_field($sformatf("RDATA[%0d]",i),RDATA[i],32,UVM_DEC);
		foreach(RRESP[i])
		printer.print_field($sformatf("RRESP[%0d]",i),RRESP[i],2,UVM_DEC);
		printer.print_field("RLAST",this.RLAST,1,UVM_DEC);
		printer.print_field("RVALID",this.RVALID,1,UVM_DEC);
		printer.print_field("RREADY",this.RREADY,1,UVM_DEC);

	endfunction
endclass

...


# code for env.sv

  ...
  class env extends uvm_env;
	`uvm_component_utils(env)

	mstr_agt_top mstr_top;
	slv_agt_top slv_top;
	scoreboard sb;
	env_config env_cfg;

	function new(string name="env",uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if(!uvm_config_db #(env_config)::get(this,"","env_config",env_cfg))
		`uvm_fatal("env","Getting env_config in env failedd!!")

		mstr_top=mstr_agt_top::type_id::create("mstr_top",this);
		slv_top=slv_agt_top::type_id::create("slv_top",this);
		sb=scoreboard::type_id::create("sb",this);
	endfunction

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		
	endfunction
endclass

...

# code for env_config.sv

  ...
  class env_cfg extends uvm_object;
	`uvm_object_utils(env_cfg)
	
	mstr_agt_cfg mstr_cfg[];
	slv_agt_cfg slv_cfg[];

	int no_of_master_agents;
	int no_of_slave_agents;
	
	function new(string name="env_cfg");
		super.new(name);
	endfunction
endclass

...

# code for scoreboard.sv

  ...
  class sb extends uvm_scoreboard;
	`uvm_component_utils(sb)

	function new(string name="sb",uvm_component parent);	
		super.new(name,parent);	
	endfunction

endclass

...

# code for top.sv

  ...
  module top;
	import uvm_pkg::*;
	import axi_pkg::*;
	//`include "uvm_macros.svh"

	bit clk;
	always #10 clk=~clk;

	axi_if vif(clk);

	initial
	begin

		`ifdef VCS
		$fsdbDumpvars(o,top);
		`endif

		uvm_config_db #(virtual axi_if)::set(null,"*","virtual axi_if",vif);
		run_test();
	end
endmodule

...
