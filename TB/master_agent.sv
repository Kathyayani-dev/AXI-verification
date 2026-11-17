# code for mstr_agt_cfg.sv

  ...
  class mstr_agt_cfg extends uvm_object;
        `uvm_object_utils(mstr_agt_cfg)

        uvm_active_passive_enum is_active=UVM_ACTIVE;

        function new(string name="mstr_agt_cfg");
                super.new(name);
        endfunction

        virtual axi_if vif;
endclass

...

# code for mstr_agt.sv

  ...
  class mstr_agt extends uvm_agent;
        `uvm_component_utils(mstr_agt)

        mstr_driver drvh;
        mstr_monitor monh;
        mstr_sequencer seqrh;
        mstr_agt_cfg mstr_cfg;

        function new(string name="mstr_agt",uvm_component parent);
                super.new(name,parent);
        endfunction

        function void build_phase(uvm_phase phase);
                super.build_phase(phase);
                if(!uvm_config_db #(mstr_agt_cfg)::get(this,"","mstr_agt_cfg",mstr_cfg))
                `uvm_fatal("In Master Agent","Getting mstr_agt_cfg has failedd!!")

                monh=mstr_monitor::type_id::create("monh",this);
                if(mstr_cfg.is_active=UVM_ACTIVE)
                seqrh=mstr_sequencer::type_id::create("seqrh",this);
                drvh=mstr_driver::type_id::create("drvh",this);
        endfunction

        function void connect_phase(uvm_phase phase);
                super.connect_phase(phase);
                drvh.seq_item_port.connect(seqrh.seq_item_export);
        endfunction

endclass

...

# code for  mstr_agt_top.sv

  ...
  class mstr_agt_top extends uvm_env;
        `uvm_component_utils(mstr_agt_top)

        mstr_agt agth[];
        mstr_agt_cfg mstr_cfg;
        env_config env_cfg;

        function new(string name="mstr_agt_top",uvm_component parent);
                super.new(name,parent);
        endfunction

        function void build_phase(uvm_phase phase);
                super.build_phase(phase);
                if(!uvm_config_db #(env_config)::get(this,"","env_config",env_cfg))
                `uvm_fatal("Master Top","Getting env_config failedd!!")

                agth=new[env_cfg.no_of_master_agents];
                foreach(agth[i])
                begin
                        agth[i]=mstr_agt::type_id::create($sformatf("agth[%0d]",i),this);
                        uvm_config_db#(mstr_agt_cfg)::set(this,$sformatf("agth[%0d]*",i),"mstr_agt_cfg",env_cfg.mstr_cfg[i]);
                end
        endfunction
endclass

...

# code for mstr_drv.sv

  ...
  class mstr_drv extends uvm_driver #(axi_xtn);
        `uvm_component_utils(mstr_drv)

        virtual axi_if vif;

        mstr_config mstr_cfg;

        axi_xtn q1[$],q2[$],q3[$],q4[$],q5[$];

        //For particular master to be worked at a time
        semaphore sem_wdcd=new(); //write data channel dependency
        semaphore sem_wrcd=new(); //write response channel dependency
        semaphore sem_wac =new(1); //write address channel
        semaphore sem_wdc =new(1); //write data channel
        semaphore sem_wrc =new(1); //write response channel

        semaphore sem_rdcd =new(); //read data channel dependency
        semaphore sem_rac =new(1); //read address channel
        semaphore sem_rdc =new(1); //read data channel

        function new(string name="mstr_drv",uvm_component parent);
                super.new(name,parent);
        endfunction

        function void build_phase(uvm_phase phase);
                super.build_phase(phase);
                if(!uvm_config_db #(mstr_config)::get(this,"","mstr_config",mstr_cfg))
                `uvm_fatal("In Master Driver","Getting mstr_config has failedd!!")
        endfunction

        function void connect_phase(uvm_phase phase);
                super.connect_phase(phase);
                vif=mstr_cfg.vif;
        endfunction

        task run_phase(uvm_phase phase);
                forever
                begin
                        seq_item_port.get_next_item(req);
                        send_to_dut(req);
                        seq_item_port.item_done();
                end
        endtask

    task send_to_dut(axi_xtn xtn);
                q1.push_back(xtn);
                q2.push_back(xtn);
                q3.push_back(xtn);
                q4.push_back(xtn);
                q5.push_back(xtn);

                fork
                        //Write Address Channel
                        begin
                                sem_wac.get(1);
                                drive_waddr(q1.pop_front());
                                sem_wdcd.put(1);
                                sem_wac.put(1);
                        end

                        //Write Data Channel
                        begin
                                sem_wdcd.get(1);
                                sem_wdc.get(1);
                                drive_wdatac(q2.pop_front());
                                sem_wdc.put(1);
                                sem_wrcd.put(1);
                        end

                        //Write Response Channel
                        begin
                                sem_wrcd.get(1);
                                sem_wrc.get(1);
                                drive_wrspc(q3.pop_front());
                                sem_wrc.put(1);
                        end

                        //Read Address Channel
                        begin
                                sem_rac.get(1);
                                driver_raddrc(q4.pop_front());
                                sem_rdcd.put(1);
                                sem_rac.put(1);
                        end
  //Read Data Channel
                        begin
                                sem_rdcd.get(1);
                                sem_rdc.get(1);
                                driver_rdata(q5.pop_front());
                                sem_rdc.put(1);
                        end
                join_any
        endtask

        task drive_waddrc(axi_xtn xtn);
                vif.mstr_drv_cb.AWVALID<=1;
                vif.mstr_drv_cb.AWADDR<=xtn.AWADDR;
                vif.mstr_drv_cb.AWSIZE<=xtn.AWSIZE;
                vif.mstr_drv_cb.AWLEN<=xtn.AWLEN;
                vif.mstr_drv_cb.AWID<=xtn.AWID;
                vif.mstr_drv_cb.AWBURST<=xtn.AWBURST;

                @(vif.mstr_drv_cb)
                wait(vif.mstr_drv_cb.AWREADY)
                vif.mstr_drv_cb.AWVALID<=1'b0;

                repeat($urandom_range(1,5))
                        @(vif.mstr_drv_cb);
        endtask

        task drive_wdatac(axi_xtn xtn);
                foreach(xtn.WDATA[i])
                begin
                        vif.mstr_drv_cb.WVALID<=1'b1;
                        vif.mstr_drv_cb.WDATA<=xtn.WDATA[i];
                        vif.mstr_drv_cb.WSTRB<=xtn.WSTRB[i];
                        vif.mstr_drv_cb.WID<=xtn.WID;
                        if(i==(xtn.AWLEN))
                                vif.mstr_drv_cb.WLAST<=1'b1;
                        else
                                vif.mstr_drv_cb.WLAST<=1'b0;

                        @(vif.mstr_drv_cb);
                        wait(vif.mstr_drv_cb.WREADY)
                        vif.mstr_drv_cb.WVALID<=1'b0;
                        vif.mstr_drv_cb.WLAST<=1'b0;

                  repeat($urandom_range(1,5))
                        @(vif.mstr_drv_cb);
                end
        endtask

        task drive_wrspc(axi_xtn xtn);
                vif.mstr_drv_cb.BREADY<=1'b1;
                @(vif.mstr_drv_cb);
                wait(vif.mstr_drv_cb.BVALID)
                        vif.mstr_drv_cb.BREADY<=1'b0;

                repeat($urandom_range(1,5))
                @(vif.mstr_drv_cb);
        endtask

        task drive_raddrc(axi_xtn xtn);
                vif.mstr_drv_cb.ARID<=xtn.ARID;
                vif.mstr_drv_cb.ARADDR<=xtn.ARADDR;
                vif.mstr_drv_cb.ARLEN<=xtn.ARLEN;
                vif.mstr_drv_cb.ARSIZE<=xtn.ARSIZE;
                vif.mstr_drv_cb.ARBURST<=xtn.ARBURST;
                vif.mstr_drv_cb.ARVALID<=1;

                @(vif.mstr_drv_cb);
                wait(vif.mstr_drv_cb.ARREADY)
                        vif.mstr_drv_cb.ARVALID<=-;
                repeat($urandom_range(1,5))
                        @(vif.mstr_drv_cb);
        endtask

        task drive_rdatac(axi_xtn xtn);
                for(int i=0; i<=(xtn.ARLEN); i++)
                begin
                        vif.mstr_drv_cb.RREADY<=1;
                        @(vif.mstr_drv_cb);
                        wait(vif.mstr_drv_cb.RVALID)
                                vif.mstr_drv_cb.RREADY<=0;
                        repeat($urandom_range(1,5))
                                @(vif.mstr_drv_cb);
                end
        endtask
  endclass

...

# code for mstr_mon.sv

  ...
  class mstr_mon extends uvm_monitor;
        `uvm_component_utils(mstr_mon)

        virtual axi_if vif;

        uvm_analysis_port#(axi_xtn) ap;
        mstr_agt_cfg mstr_cfg;

        axi_xtn xtn,xtn1;
        axi_xtn q1[$],q2[$],q3[$],q4[$],q5[$];

        //For particular master to be worked at a time
        semaphore sem_wdcd=new(); //Write data channel dependency
        semaphore sem_wrcd=new(); //write response channel dependency
        semaphore sem_wac =new(1); //write address channel
        semaphore sem_wdc =new(1); //write data channel
        semaphore sem_wrc =new(1); //write response channel
        semaphore sem_rdcd=new(); //read data channel dependency
        semaphore sem_rac =new(1); //read address channel
        semaphore sem_rdc =new(1); //read data channel

        function new(string name="mstr_mon", uvm_component parent);
                super.new(name,parent);
                ap=new("ap",this);
        endfunction

        function void build_phase(uvm_phase phase);
                super.build_phase(phase);
                if(!uvm_config_db#(mstr_agt_cfg)::get(this,"","mstr_agt_cfg",mstr_cfg)
                        `uvm_fatal("In Master Monitor","Getting mstr_agt_cfg failedd!!")
        endfunction

        function void connect_phase(uvm_phase phase);
                super.connect_phase(phase);
                vif=mstr_cfg.vif;
        endfunction

        task run_phase(uvm_phase phase);
                forever
                        collect_data();
        endtask
 task collect_data();
                fork
                        //Write Address
                        begin
                                sem_wac.get();
                                collect_waddrc();
                                sem_wdcd.put(1);
                                sem_wac.put(1);
                        end

                        //Write Data
                        begin
                                sem_wdcd.get(1);
                                sem_wdc.get(1);
                                collect_wdatac(q1.pop_front());
                                sem_wrcd.put(1);
                                sem_wdc.put(1);
                        end

                        //Write Response
                        begin
                                sem_wrcd.get(1);
                                sem_wrc.get(1);
                                collect_wrspc(q2.pop_front());
                                sem_wrc.put(1);
                        end

                        //Read Address
                        begin
                                sem_rac.get(1);
                                collect_raddrc();
                                sem_rac.put(1);
                                sem_rac.put(1);
                        end

                        //Read Data
                        begin
                                sem_rdcd.get(1);
                                sem_rdc.get(1);
collect_rdatac(q3.pop_front());
                                sem_rdc.put(1);
                        end
                join_any
        endtask

        task collect_waddrc();
                xtn=axi_xtn::type_id::create("xtn");
                @(vif.mstr_mon_cb);
                wait((vif.mstr_mon_cb.AWVALID) && (vif.mstr_mon_cb.AWREADY))
                xtn.AWID=vif.mstr_mon_cb.AWID;
                xtn.AWADDR=vif.mstr_mon_cb.AWADDR;
                xtn.AWLEN=vif.mstr_mon_cb.AWLEN;
                xtn.AWSIZE=vif.mstr_mon_cb.AWSIZE;
                xtn.AWBURST=vif.mstr_mon_cb.AWBURST;
                xtn.AWVALID=vif.mstr_mon_cb.AWVALID;
                xtn.AWREADY=vif.mstr_mon_cb.AWREADY;

                q1.push_back(xtn);
        endtask

        task collect_wdatac(axi_xtn xtn);
                xtn.WDATA = new[xtn.AWLEN+1];
                xtn.WSTRB = new[xtn.AWLEN+1];
                foreach(xtn.WDATA[i])
                begin
                        wait(vif.mstr_mon_cb.WVALID && vif.mstr_mon_cb.WREADY)
                        xtn.WSTRB[i] = vif.mstr_mon_cb.WSTRB;
                        if(vif.mstr_mon_cb.WSTRB == 15)
                                xtn.WDATA[i] = vif.mstr_mon_cb.WDATA;

                        if(vif.mstr_mon_cb.WSTRB == 8)
                                xtn.WDATA[i] = vif.mstr_mon_cb.WDATA[31:24];

                        if(vif.mstr_mon_cb.WSTRB == 4)
                                xtn.WDATA[i] = vif.mstr_mon_cb.WDATA[23:16];

                        if(vif.mstr_mon_cb.WSTRB == 2)
                                xtn.WDATA[i] = vif.mstr_mon_cb.WDATA[15:8];
if(vif.mstr_mon_cb.WSTRB == 1)
                                xtn.WDATA[i] = vif.mstr_mon_cb.WDATA[7:0];

                        if(vif.mstr_mon_cb.WSTRB == 14) //unalligned strb 4 bytes 1110
                                xtn.WDATA[i] = vif.mstr_mon_cb.WDATA[31:8];

                        if(vif.mstr_mon_cb.WSTRB == 12)
                                xtn.WDATA[i] = vif.mstr_mon_cb.WDATA[31:16];

                        if(vif.mstr_mon_cb.WSTRB == 3)
                                xtn.WDATA[i] = vif.mstr_mon_cb.WDATA[15:0];

                                xtn.WID = vif.mstr_mon_cb.WID;
                                xtn.WLAST = vif.mstr_mon_cb.WLAST;
                                xtn.WVALID = vif.mstr_mon_cb.WVALID;
                                @(vif.mstr_mon_cb);
                end
                q2.push_back(xtn);
        endtask

        task collect_wrspc(axi_xtn xtn);
                @(vif.mstr_mon_cb);
                wait(vif.mstr_mon_cb.BREADY && vif.mstr_mon_cb.BVALID)
                        xtn.BREADY=vif.mstr_mon_cb.BREADY;
                        xtn.BID=vif.mstr_mon_cb.BID;
                        xtn.BRESP=vif.mstr_mon_cb.BRESP;
                        xtn.BVALID=vif.mstr_mon_cb.BVALID;
                @(vif.mstr_mon_cb);
                ap.write(xtn);
        endtask

        task collect_raddrc();
                xtn1=axi_xtn::type_id::create("xtn1");
                @(vif.mstr_mon_cb)
                wait(vif.mstr_mon_cb.ARVALID && vif.mstr_mon_cb.ARREADY)
                        xtn1.ARID=vif.mstr_mon_cb.ARID;
                        xtn1.ARADDR=vif.mstr_mon_cb.ARADDR;
                        xtn1.ARLEN=vif.mstr_mon_cb.ARLEN;
  xtn1.ARSIZE=vif.mstr_mon_cb.ARSIZE;
                        xtn1.ARBURST=vif.mstr_mon_cb.ARBURST;
                        xtn1.ARVALID=vif.mstr_mon_cb.ARVALID;
                        xtn1.ARREADY=vif.mstr_mon_cb.ARREADY;

                        q3.push_back(xtn1);
        endtask

        task collect_rdatac(axi_xtn xtn1);
                xtn1.RDATA=new[xtn1.ARLEN+1];
                xtn1.RRESP = new[xtn1.ARLEN+1];
                foreach(xtn1.RDATA[i])
                begin
                        @(vif.mstr_mon_cb);
                        wait(vif.mstr_mon_cb.RVALID && vif.mstr_mon_cb.RREADY);
                                xtn1.RID=vif.mstr_mon_cb.RID;
                                xtn1.RVALID=vif.mstr_mon_cb.RVALID;
                                xtn1.RREADY=vif.mstr_mon_cb.RREADY;
                                xtn1.RDATA[i]=vif.mstr_mon_cb.RDATA;
                                xtn1.RRESP[i]=vif.mstr_mon_cb.RRESP;
                        if(i==xtn1.ARLEN)
                                xtn1.RLAST=vif.mstr_mon_cb.RLAST;
                end
                ap.wite(xtn1);
        endtask
endclass

...

# code for mstr_seqr.sv

  ...
  class mstr_seqr extends uvm_sequencer #(axi_xtn);
        `uvm_component_utils(mstr_seqr)

        function new(string name="mstr_seqr",uvm_component parent);
                super.new(name,parent);
        endfunction
  endclass

  ...

# code for mstr_seqs.sv

  ...
  class mstr_seqs extends uvm_sequence #(axi_xtn);
        `uvm_object_utils(mstr_seqs)

        function new(string name="mstr_seqs");
                super.new(name);
        endfunction
endclass

class fixed extends mstr_seqs;
        `uvm_object_utils(fixed)

        axi_xtn xtn;

        function new(string name= "fixed");
                super.new(name);
        endfunction

        task body();
                repeat(4)
                begin
                        xtn=axi_xtn::type_id::create("xtn");
                        start_item(xtn);
                        assert(xtn.randomize() with {AWBURST==2'b00;AWADDR=='d4;AWSIZE==2; ARLEN==3;});
                        finish_item(xtn);
                end
        endtask
endclass

class increment extends mstr_seqs;
        `uvm_object_utils(increment)

        function new(string name = "increment");
                super.new(name);
        endfunction

        axi_xtn xtn;

        task body();
                repeat(5)
                begin
                        xtn=axi_xtn::type_id::create("xtn");
start_item(xtn);
                        assert(xtn.randomize() with {AWBURST==2'b01;AWADDR=='d4;AWLEN==2;AWSIZE==1;});
                        finish_item(xtn);
                end
        endtask
endclass


class wrap extends mstr_seqs;
        `uvm_object_utils(wrap)

        axi_xtn xtn;

        function new(string name="wrap");
                super.new(name);
        endfunction

        task body();
                repeat(6)
                begin
                        xtn=axi_xtn::type_id::create("xtn");
                        start_item(xtn);
                        assert(xtn.randomize() with {AWBURST==2'b10;});
                        finish_item(xtn);
                end
        endtask
endclass


class unaligned extends mstr_seqs;
        `uvm_object_utils(unaligned)

        function new(string name = "unaligned");
                super.new(name);
        endfunction

        axi_xtn xtn;

   task body();
                repeat(5)
                begin
                        xtn=axi_xtn::type_id::create("xtn");
                        start_item(xtn);
                        assert(xtn.randomize() with {AWBURST==2'b01;AWADDR=='d13;});
                        finish_item(xtn);
                end
        endtask
endclass

...

...
