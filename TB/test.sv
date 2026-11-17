# code for axi_pkg.sv

  ...
  package axi_pkg;
        import uvm_pkg::*;
        `include "uvm_macros.svh"

        `include "mstr_agt_cfg.sv"
        `include "slv_agt_cfg.sv"
        `include "env_config.sv"

        `include "axi_xtn.sv"

        `include "mstr_seqs.sv"
        `include "mstr_seqr.sv"
        `include "mstr_drv.sv"
        `include "mstr_mon.sv"
        `include "mstr_agt.sv"
        `include "mstr_agt_top.sv"

        `include "slv_seqs.sv"
        `include "slv_seqr.sv"
        `include "slv_drv.sv"
        `include "slv_mon.sv"
        `include "slv_agt.sv"
        `include "slv_agt_top.sv"

        `include "scoreboard.sv"
        `include "env.sv"
        `include "test.sv"
endpackage

...

# code for test.sv

  ...
  class test extends uvm_test;
        `uvm_component_utils(test)

        function new(string name="test",uvm_component parent);
                super.new(name,parent);
        endfunction

        function void build_phase(uvm_phase phase);
                super.build_phase(phase);
        endfunction

        function void end_of_elaboration_phase(uvm_phase phase);
                uvm_top.print_topology();
        endfunction
  endclass

  ...

