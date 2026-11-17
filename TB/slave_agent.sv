# code for slv_agt_cfg.sv

...
  class slv_agt_cfg extends uvm_object;
        `uvm_object_utils(slv_agt_cfg)

        uvm_active_passive_enum is_active=UVM_ACTIVE;

        function new(string name="slv_agt_cfg");
                super.new(name);
        endfunction

        virtual axi_if vif;

endclass

...

# code for slv_agt.sv

  ...
  class slv_agt extends uvm_agent;
        `uvm_component_utils(slv_agt)

        slv_agt_cfg slv_cfg;
        slv_drv drvh;
        slv_mon monh;
        slv_seqr seqrh;

        function new(string name="slv_agt",uvm_component parent);
                super.new(name,parent);
        endfunction

        function void build_phase(uvm_phase phase);
                if(!uvm_config_db#(slv_agt_cfg)::get(this,"","slv_agt_cfg",slv_cfg))
                        `uvm_fatal("In Slave"Agent,"Getting slv_agt_cfg has failedd!!")

                monh=slv_mon::type_id::create("monh",this);
                if(slv_cfg.is_active == UVM_ACTIVE)
                begin
                        drvh=slv_drv::type_id::create("drvh",this);
                        seqrh=slv_seqr::type_id::create("seqrh",this);
                end
        endfunction

        function  void connect_phase(uvm_phase phase);
                drvh.seq_item_port.connect(seqrh.seq_item_export);
        endfunction
endclass

...

# code for slv_agt_top.sv

  ...
    class slv_agt_top extends uvm_env;  
      `uvm_component_utils(slv_agt_top)

        slv_agt slv_agth[];
        slv_agt_cfg slv_cfg;
        env_config env_cfg;

        function new(string name="slv_agt_top",uvm_component parent);
                super.new(name,parent);
        endfunction

        function void build_phase(uvm_phase phase);
                super.build_phase(phase);
                if(!uvm_config_db#(env_config)::get(this,"","env_config",env_cfg))
                `uvm_fatal("In Slv Agent Top","Getting env_config has failedd!!")
                 slv_agth=new[env_cfg.no_of_slave_agents];
                 foreach(slave_agth[i])
                 begin
                        slv_agth[i]=slv_agt::type_id::create($sformatf("slv_agth[%0d]",i),this);
                        uvm_config_db#(slv_agt_cfg)::set(this,$sformatf("slv_agth[%0d]*",i),"slv_agt_cfg",env_cfg.slv_cfg[i]);
                 end
        endfunction
endclass

...

# code for slv_drv.sv

  ...
  class slv_drv extends uvm_driver #(axi_xtn);
        `uvm_component_utils(slv_drv)

        virtual axi_if vif;

        slv_agt_cfg slv_cfg;

        axi_xtn q1[$],q2[$],q3[$];
        axi_xtn xtn;

        //for particular slave to be worked at a time//
        semaphore sem_wdcd = new();//write data channel dependency//
        semaphore sem_wrcd = new();//write reponse channel dependency//
        semaphore sem_wdc  = new(1);//WRITE data channnel
        semaphore sem_wac  = new(1);//write address channel
        semaphore sem_wrc  = new(1);//write respose


        semaphore sem_rdcd = new();//read data channel dependency
        semaphore sem_rac  = new(1);//read address
        semaphore sem_rdc  = new(1);//read data channel

        function new(string name="slv_drv",uvm_component parent);
                super.new(name,parent);
        endfunction

        function void build_phase(uvm_phase phase);
                super.build_phase(phase);
                if(!uvm_config_db#(slv_agt_cfg)::get(this,"","slv_agt_cfg",slv_cfg))
                        `uvm_fatal("slave_driver","config is not getting")
        endfunction

        function void connect_phase(uvm_phase phase);
                super.connect_phase(phase);
                vif=slv_cfg.vif;
        endfunction

        task run_phase(uvm_phase phase);
                 forever
                 begin
                        slave_drive();
                 end
        endtask

    task slave_drive();
                fork
                        //write address
                        begin
                                sem_wac.get(1);
                                drive_waddrc();
                                sem_wdcd.put(1);
                                sem_wac.put(1);
                        end

                        //write data
                        begin
                                sem_wdcd.get(1);
                                sem_wdc.get(1);
                                drive_wdatac(q1.pop_front());
                                sem_wrcd.put(1);
                                sem_wdc.put(1);
                        end

                        //write response
                        begin
                                sem_wrcd.get(1);
                                sem_wrc.get(1);
                                drive_wrespc(q2.pop_front());
                                sem_wrc.put(1);
                        end

                        //read address
                        begin
                                sem_rac.get(1);
                                drive_raddrc();
                                sem_rdcd.put(1);
                                sem_rac.put(1);
                        end

                        //read data
                        begin
                                sem_rdcd.get(1);
                                sem_rdc.get(1);
                                drive_rdatac(q3.pop_front());
                                sem_rdc.put(1);
                        end
                join_any
        endtask

        task drive_waddrc();
                xtn=axi_xtn::type_id::create("xtn");
                vif.slv_drv_cb.AWREADY<=1;
                @(vif.slv_drv_cb);
                wait(vif.slv_drv_cb.AWVALID)
                        xtn.AWID = vif.slv_drv_cb.AWID;
                        xtn.AWLEN = vif.slv_drv_cb.AWLEN;
                        xtn.AWADDR = vif.slv_drv_cb.AWADDR;
                        xtn.AWSIZE = vif.slv_drv_cb.AWSIZE;
                        xtn.AWBURST = vif.slv_drv_cb.AWBURST;
                        xtn.AWVALID = vif.slv_drv_cb.AWVALID;
                        xtn.AWREADY = vif.slv_drv_cb.AWREADY;

                        vif.slv_drv_cb.AWREADY<=0;

                        q1.push_back(xtn);

                        repeat($urandom_range(1,5))
                        @(vif.slv_drv_cb);
        endtask

        task drive_wdatac(axi_xtn xtn);
                for(int i=0;i<xtn.AWLEN+1;i++)
                begin
                        vif.slv_drv_cb.WREADY<=1;
                        @(vif.slv_drv_cb);
                        wait(vif.slv_drv_cb.WVALID)
                                xtn.WID = vif.slv_drv_cb.WID;
                                xtn.WDATA[i] = vif.slv_drv_cb.WDATA;
                                xtn.WSTRB[i]  = vif.slv_drv_cb.WSTRB;
                                xtn.WLAST = vif.slv_drv_cb.WLAST;
                                xtn.WVALID = vif.slv_drv_cb.WVALID;
                                xtn.WREADY = vif.slv_drv_cb.WREADY;

                   vif.slv_drv_cb.WREADY<=0;
                end

                repeat($urandom_range(1,5))
                @(vif.slv_drv_cb);
                q2.push_back(xtn);
        endtask

        task drive_wrespc(axi_xtn xtn);
                vif.slv_drv_cb.BID <=xtn.WID;
                vif.slv_drv_cb.BRESP <=0;
                vif.slv_drv_cb.BVALID <= 1;
                @(vif.slv_drv_cb);
                wait(vif.slv_drv_cb.BREADY)
                        xtn.BID = vif.slv_drv_cb.WID;
                        xtn.BRESP = vif.slv_drv_cb.BRESP;
                        xtn.BVALID = vif.slv_drv_cb.BVALID;
                        xtn.BREADY = vif.slv_drv_cb.BREADY;

                vif.slv_drv_cb.BVALID <= 0;
                repeat($urandom_range(1,5))
                @(vif.slv_drv_cb);
        endtask

        task drive_raddrc();
                vif.slv_drv_cb.ARREADY <=1;
                @(vif.slv_drv_cb);
                wait(vif.slv_drv_cb.ARVALID)
                        xtn.ARID = vif.slv_drv_cb.ARID;
                        xtn.ARLEN = vif.slv_drv_cb.ARLEN;
                        xtn.ARADDR = vif.slv_drv_cb.ARADDR;
                        xtn.ARSIZE = vif.slv_drv_cb.ARSIZE;
                        xtn.ARBURST = vif.slv_drv_cb.ARBURST;
                        xtn.ARVALID = vif.slv_drv_cb.ARVALID;
                        xtn.ARREADY = vif.slv_drv_cb.ARREADY;

                vif.slv_drv_cb.ARREADY <=0;
                q3.push_back(xtn);
                repeat($urandom_range(1,5))
                @(vif.slv_drv_cb);
        endtask

     task drive_rdatac(axi_xtn xtn);
                xtn.RDATA = new[xtn.ARLEN+1];
                foreach(xtn.RDATA[i])
                begin
                        vif.slv_drv_cb.RVALID <= 1;
                        vif.slv_drv_cb.RRESP <=0;
                        vif.slv_drv_cb.RID <=xtn.ARID;
                        vif.slv_drv_cb.RDATA <=$urandom_range(1,500);
                        if(i==(xtn.ARLEN))
                                vif.slv_drv_cb.RLAST <= 1;
                        else
                                vif.slv_drv_cb.RLAST <= 0;

                        @(vif.slv_drv_cb);
                        wait(vif.slv_drv_cb.RREADY)
                                xtn.RVALID = vif.slv_drv_cb.RVALID;
                                xtn.RREADY = vif.slv_drv_cb.RREADY;
                                xtn.RDATA[i] = vif.slv_drv_cb.RDATA;

                                vif.slv_drv_cb.RVALID <= 0;
                                vif.slv_drv_cb.RLAST <= 0;
                        repeat($urandom_range(1,5))
                        @(vif.slv_drv_cb);
                end
        endtask
endclass

...

# code for slv_mon.sv

  ...
  class slv_mon extends uvm_monitor;
        `uvm_component_utils(slv_mon)

        virtual axi_if vif;
        uvm_analysis_port#(axi_xtn) ap;
        slv_agt_cfg slv_cfg;

        axi_xtn xtn,xtn1;
        axi_xtn q1[$],q2[$],q3[$];

        //for particular master to be worked at a time
        semaphore sem_wdcd = new();//write data channel dependency
        semaphore sem_wrcd = new();//write reponse channel dependency
        semaphore sem_wdc  = new(1);//WRITE data channnel
        semaphore sem_wac  = new(1);//write address channel
        semaphore sem_wrc  = new(1);//write respose
        semaphore sem_rdcd = new();//read data channel dependency
        semaphore sem_rac  = new(1);//read address
        semaphore sem_rdc  = new(1);//read data channel

        function new(string name="slv_mon",uvm_component parent);
                super.new(name,parent);
                ap=new("ap",this);
        endfunction

        function void build_phase(uvm_phase phase);
                super.build_phase(phase);
                if(!uvm_config_db#(slv_agt_cfg)::get(this,"","slv_agt_cfg",slv_cfg))
                                `uvm_fatal("slave_monitor","config is not getting");
        endfunction

        function void connect_phase(uvm_phase phase);
                super.connect_phase(phase);
                vif=slv_cfg.vif;
        endfunction

        task run_phase(uvm_phase phase);
                forever
                        collect_data();
        endtask

        task collect_data();
                fork
                                //write address//
                                begin
                                        sem_wac.get(1);
                                        collect_waddrc();
                                        sem_wdcd.put(1);
                                        sem_wac.put(1);
                                end


                                //write data//
                                begin
                                        sem_wdcd.get(1);
                                        sem_wdc.get(1);
                                        collect_wdatac(q1.pop_front());
                                        sem_wrcd.put(1);
                                        sem_wdc.put(1);
                                end



                                //write response//
                                begin
                                        sem_wrcd.get(1);
                                        sem_wrc.get(1);
                                        collect_wrspc(q2.pop_front());
                                        sem_wrc.put(1);
                                end

                                //read address//
                                begin
                                        sem_rac.get(1);
                                        collect_raddrc();
                                        sem_rdcd.put(1);
                                        sem_rac.put(1);
                                end
 
                                //read data//
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

                @(vif.slv_mon_cb);

                wait((vif.slv_mon_cb.AWVALID) && (vif.slv_mon_cb.AWREADY))
                xtn.AWID=vif.slv_mon_cb.AWID;
                xtn.AWADDR=vif.slv_mon_cb.AWADDR;
                xtn.AWLEN=vif.slv_mon_cb.AWLEN;
                xtn.AWSIZE=vif.slv_mon_cb.AWSIZE;
                xtn.AWBURST=vif.slv_mon_cb.AWBURST;
                xtn.AWVALID=vif.slv_mon_cb.AWVALID;
                xtn.AWREADY=vif.slv_mon_cb.AWREADY;
                q1.push_back(xtn);
        endtask

        task collect_wdatac(axi_xtn xtn);
                xtn.WDATA = new[xtn.AWLEN+1];
                xtn.WSTRB = new[xtn.AWLEN+1];
                        foreach(xtn.WDATA[i])
                                begin
                                        wait(vif.slv_mon_cb.WVALID && vif.slv_mon_cb.WREADY)
                                                xtn.WSTRB[i] = vif.slv_mon_cb.WSTRB;
                                                        if(vif.slv_mon_cb.WSTRB == 15)
                                                                xtn.WDATA[i] = vif.slv_mon_cb.WDATA;
                                     if(vif.slv_mon_cb.WSTRB == 8)
                                                                xtn.WDATA[i] = vif.slv_mon_cb.WDATA[31:24];

                                                        if(vif.slv_mon_cb.WSTRB == 4)
                                                                xtn.WDATA[i] = vif.slv_mon_cb.WDATA[23:16];

                                                        if(vif.slv_mon_cb.WSTRB == 2)
                                                                xtn.WDATA[i] = vif.slv_mon_cb.WDATA[15:8];

                                                        if(vif.slv_mon_cb.WSTRB == 1)
                                                                xtn.WDATA[i] = vif.slv_mon_cb.WDATA[7:0];

                                                        if(vif.slv_mon_cb.WSTRB == 14)
                                                                xtn.WDATA[i] = vif.slv_mon_cb.WDATA[31:8];

                                                        if(vif.slv_mon_cb.WSTRB == 12)
                                                                xtn.WDATA[i] = vif.slv_mon_cb.WDATA[31:16];

                                                        if(vif.slv_mon_cb.WSTRB == 3)
                                                                xtn.WDATA[i] = vif.slv_mon_cb.WDATA[15:0];

                                                        xtn.WID = vif.slv_mon_cb.WID;
                                                        xtn.WLAST = vif.slv_mon_cb.WLAST;
                                                        xtn.WVALID = vif.slv_mon_cb.WVALID;
                                                        @(vif.slv_mon_cb);
                                end
        endtask

        task collect_wrspc(axi_xtn xtn);
                @(vif.slv_mon_cb);
                wait(vif.slv_mon_cb.BREADY && vif.slv_mon_cb.BVALID)
                        xtn.BREADY=vif.slv_mon_cb.BREADY;
                        xtn.BID=vif.slv_mon_cb.BID;
                        xtn.BRESP=vif.slv_mon_cb.BRESP;
                        xtn.BVALID=vif.slv_mon_cb.BVALID;
                @(vif.slv_mon_cb);
                ap.write(xtn);
        endtask

        task collect_raddrc();
                xtn1=axi_xtn::type_id::create("xtn1");
                @(vif.slv_mon_cb);
                wait(vif.slv_mon_cb.ARVALID && vif.slv_mon_cb.ARREADY)
                        xtn1.ARID=vif.slv_mon_cb.ARID;
                        xtn1.ARADDR=vif.slv_mon_cb.ARADDR;
                        xtn1.ARLEN=vif.slv_mon_cb.ARLEN;
                        xtn1.ARSIZE=vif.slv_mon_cb.ARSIZE;
                        xtn1.ARBURST=vif.slv_mon_cb.ARBURST;
                        xtn1.ARVALID=vif.slv_mon_cb.ARVALID;
                        xtn1.ARREADY=vif.slv_mon_cb.ARREADY;

                        q3.push_back(xtn1);
        endtask

        task collect_rdatac(axi_xtn xtn1);
                xtn1.RDATA=new[xtn1.ARLEN+1];
                xtn1.RRESP = new[xtn1.ARLEN+1];
                foreach(xtn1.RDATA[i])
                begin
                        @(vif.slv_mon_cb);
                        wait(vif.slv_mon_cb.RVALID && vif.slv_mon_cb.RREADY);
                                xtn1.RID=vif.slv_mon_cb.RID;
                                xtn1.RVALID=vif.slv_mon_cb.RVALID;
                                xtn1.RREADY=vif.slv_mon_cb.RREADY;
                                xtn1.RDATA[i]=vif.slv_mon_cb.RDATA;
                                xtn1.RRESP[i]=vif.slv_mon_cb.RRESP;
                        if(i==xtn1.ARLEN)
                                xtn1.RLAST=vif.slv_mon_cb.RLAST;
                end
        endtask
endclass

...

# code for slv_seqr.sv

...
class slv_seqr extends uvm_sequencer #(axi_xtn);
        `uvm_component_utils(slv_seqr)

        function new(string name="slv_seqr",uvm_component parent);
                super.new(name,parent);
        endfunction
endclass

...

# code for slv_seqs.sv

...
  class slv_seqs extends uvm_sequence #(axi_xtn);
        `uvm_object_utils(slv_seqs)

        function new(string name="slv_seqs");
                super.new(name);
        endfunction
  endclass

...




