`timescale 1ns / 1ps


//////////                              Transaction
`include "uvm_macros.svh"
import uvm_pkg::*;

class transaction extends uvm_sequence_item;
  rand bit [3:0] a;
  rand bit [3:0] b;
  rand bit [3:0] c;
  rand bit [3:0] d;
  rand bit [1:0] sel;
  bit [3:0] y;

  function new(input string path = "transaction");
    super.new(path);
  endfunction
  
  
//    Starts defining how the transaction class should be registered with the UVM factory system.
  
`uvm_object_utils_begin(transaction)
  `uvm_field_int(a, UVM_DEFAULT)
  `uvm_field_int(b, UVM_DEFAULT)
  `uvm_field_int(c, UVM_DEFAULT)
  `uvm_field_int(d, UVM_DEFAULT)
  `uvm_field_int(sel, UVM_DEFAULT)
  `uvm_field_int(y, UVM_DEFAULT)
`uvm_object_utils_end

endclass

////////                               Generator

class generator extends uvm_sequence #(transaction);
`uvm_object_utils(generator)

transaction t;
integer i;

  function new(input string path = "generator");
    super.new(path);
  endfunction


virtual task body();
  
  t = transaction::type_id::create("t");
  
  repeat(10)
    
    begin
      
    start_item(t);
      
   if (!this.t.randomize()) begin
  `uvm_error("RANDOMIZE", "Randomization failed for transaction")
   end
      `uvm_info("GEN",$sformatf("Data send to Driver a :%0d , b :%0d  , c:%0d , d :%d  , sel : %0d",t.a,t.b,t.c,t.d,t.sel), UVM_NONE);
    finish_item(t);
      
    end
endtask

endclass

//////                                     Driver


class driver extends uvm_driver #(transaction);
`uvm_component_utils(driver)

    function new(input string path = "driver", uvm_component parent = null);
      super.new(path, parent);
     endfunction

transaction tc;
virtual mux_if aif;


    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      tc = transaction::type_id::create("tc");

      if(!uvm_config_db #(virtual mux_if)::get(this,"","aif",aif)) 
      `uvm_error("DRV","Unable to access uvm_config_db");
    endfunction

    virtual task run_phase(uvm_phase phase);
    forever begin
      
    seq_item_port.get_next_item(tc);
      
    aif.a <= tc.a;
    aif.b <= tc.b;
    aif.c <= tc.c;
    aif.d <= tc.d;
    aif.sel <= tc.sel;  
      `uvm_info("DRV", $sformatf("Trigger DUT a: %0d ,b :  %0d , c: %0d , d :  %0d , sel :%0d ",tc.a, tc.b ,tc.c , tc.d , tc.sel ), UVM_NONE); 
   
    #5;  
      seq_item_port.item_done(); 
    end
    endtask
endclass



////////                          monitor 


class monitor extends uvm_monitor;
`uvm_component_utils(monitor)

uvm_analysis_port #(transaction) send;

  function new(input string path = "monitor", uvm_component parent = null);
    super.new(path, parent);
    send = new("send", this);
  endfunction

  transaction t;
  virtual mux_if aif;

  virtual function void build_phase(uvm_phase phase);
   super.build_phase(phase);
   
    
    if(!uvm_config_db #(virtual mux_if)::get(this,"","aif",aif)) 
   `uvm_error("MON","Unable to access uvm_config_db");
  endfunction

    virtual task run_phase(uvm_phase phase);
    forever begin
    #5; // Small delay for signal stabilization
    t = transaction::type_id::create("t");
    t.a = aif.a;
    t.b = aif.b;
    t.c = aif.c;
    t.d = aif.d;
    t.sel=aif.sel;
    t.y = aif.y;
    `uvm_info("MON", $sformatf("Data send to Scoreboard a: %0d ,b :  %0d , c: %0d , d :  %0d , sel :%0d ,y :%0d ",t.a, t.b ,t.c , t.d , t.sel , t.y ), UVM_NONE);
    send.write(t);
    end
    endtask
endclass


////                                Scoreboard 


class scoreboard extends uvm_scoreboard;
`uvm_component_utils(scoreboard)

  //Every time the monitor sends a transaction, the scoreboard automatically receives it into the write() function.
  
  uvm_analysis_imp #(transaction,scoreboard) recv;

transaction tr;
    reg [3:0] expected;

  function new(input string path = "scoreboard", uvm_component parent = null);
    super.new(path, parent);
    recv = new("recv", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
  super.build_phase(phase);
    tr = transaction::type_id::create("tr");
  endfunction
  
  virtual function void write(input transaction t);
  tr = t;
  `uvm_info("SCO",$sformatf("Data rcvd from Monitor a: %0d ,b: %0d ,c: %0d ,d: %0d ,sel: %0d", t.a, t.b, t.c, t.d, t.sel), UVM_NONE);
  case (tr.sel)
      2'b00: expected = tr.a;
      2'b01: expected = tr.b;
      2'b10: expected = tr.c;
      2'b11: expected = tr.d;
    endcase
    
    if (tr.y == expected)
      `uvm_info("SCO",$sformatf("Test Passed :Expected: %0d, Got: %0d", expected, tr.y ), UVM_NONE)
    else
      `uvm_error("SCO", $sformatf("Test Failed! Expected: %0d, Got: %0d", expected, tr.y))

endfunction

  
  
  
endclass
      
      
/////////           agent 
        
class agent extends uvm_agent;
`uvm_component_utils(agent)


function new(input string inst = "AGENT", uvm_component c);
super.new(inst, c);
endfunction

monitor m;
driver d;
uvm_sequencer #(transaction) seqr;


virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);
  m = monitor::type_id::create("m",this);
  d = driver::type_id ::create("d",this);
  seqr = uvm_sequencer #(transaction)::type_id::create("seqr",this);
endfunction


virtual function void connect_phase(uvm_phase phase);
super.connect_phase(phase);
  d.seq_item_port.connect(seqr.seq_item_export);
endfunction
endclass

    
///////                   enviroment 
    

class env extends uvm_env;
`uvm_component_utils(env)


function new(input string inst = "ENV", uvm_component c);
super.new(inst, c);
endfunction

scoreboard s;
agent a;

virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);
  s = scoreboard::type_id::create("s",this);
  a = agent::type_id::create("a",this);
endfunction


virtual function void connect_phase(uvm_phase phase);
super.connect_phase(phase);
a.m.send.connect(s.recv);

`uvm_info("ENV", "Monitor-Scoreboard connection established", UVM_MEDIUM)
  
endfunction

endclass

    
/////                                     test 

    
class test extends uvm_test;
`uvm_component_utils(test)


function new(input string inst = "TEST", uvm_component c);
super.new(inst, c);
endfunction

generator gen;
env e;

virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);
  gen = generator::type_id::create("gen");
  e = env::type_id::create("e",this);
endfunction

virtual task run_phase(uvm_phase phase);
   phase.raise_objection(this);
   gen.start(e.a.seqr);
   #200;
   phase.drop_objection(this);
endtask


endclass
 
    
/////                                    testbench 
    

module tb();

  mux_if aif();
 mux dut (
   .a(aif.a),
   .b(aif.b),
   .c(aif.c),
   .d(aif.d),
   .sel(aif.sel),
   .y(aif.y)
  );

initial begin
$dumpfile("dump.vcd");
$dumpvars;
end
  
initial begin  
  uvm_config_db #(virtual mux_if)::set(null, "*", "aif", aif);
run_test("test");
end

endmodule
