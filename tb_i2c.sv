
`include "uvm_macros.svh"
import uvm_pkg::*;

interface i2c_intf (
    input logic clk,
    input logic reset
);

    // Master Control Signals (Driven by Driver)
    logic i2c_start;
    logic i2c_stop;
    logic i2c_enable;
    logic [7:0] tx_data_m;  // Master's data input

    // Master Status Signals (Monitored by Monitor)
    logic tx_ready_m;
    logic tx_done_m;
    logic [7:0] rx_data_m;
    logic rx_done_m;

    // Slave Control/Status Signals (Monitored by Scoreboard)
    logic [7:0] tx_data_s;
    logic tx_ready_s;
    logic tx_done_s;
    logic [7:0] rx_data_s;  // Slave's received data
    logic rx_done_s;

    // I2C Bus Signals
    logic scl;

    wire sda;

endinterface  // i2c_intf


////////////////////////////////////////////////////////////////////////////////
//
// 2. TRANSACTION: The I2C Data Packet (Write Only)
//
////////////////////////////////////////////////////////////////////////////////

class i2c_seq_item extends uvm_sequence_item;

    bit [6:0] SLAVE_ADDR = 7'b0000001;  // Slave Address (7 bits)
    bit rw_bit = 1'b0;  // Fixed to WRITE
    rand bit [7:0] data;  // Data to be written 
    bit [7:0] s_data;

    function new(string name = "TRANSACTION");
        super.new(name);
    endfunction

    constraint data_c {data inside {[0 : 255]};}

    `uvm_object_utils_begin(i2c_seq_item)
        `uvm_field_int(SLAVE_ADDR, UVM_DEFAULT)
        `uvm_field_int(rw_bit, UVM_DEFAULT)
        `uvm_field_int(data, UVM_DEFAULT)
        `uvm_field_int(s_data, UVM_DEFAULT)
    `uvm_object_utils_end

endclass


////////////////////////////////////////////////////////////////////////////////
//
// 3. SEQUENCE & SEQUENCER: Test Stimulus Generation (Write Only)
//
////////////////////////////////////////////////////////////////////////////////

class i2c_write_sequence extends uvm_sequence #(i2c_seq_item);
    `uvm_object_utils(i2c_write_sequence)


    i2c_seq_item tr;

    function new(string name = "SEQ");
        super.new(name);
    endfunction

    task body();
        #10;
        tr = i2c_seq_item::type_id::create("SEQ");
        for (int i = 0; i < 256; i++) begin
            start_item(tr);
            if (!tr.randomize()) `uvm_error("SEQ", "Randomize failed for WRITE item");
            `uvm_info("SEQ", $sformatf("Writing Data: Addr=%0h, Data=%0h", tr.SLAVE_ADDR, tr.data), UVM_NONE)
            finish_item(tr);
        end
    endtask
endclass  // i2c_write_sequence


////////////////////////////////////////////////////////////////////////////////
//
// 4. DRIVER: Master Control Signal Generation (Write Only)
//
////////////////////////////////////////////////////////////////////////////////

class i2c_driver extends uvm_driver #(i2c_seq_item);
    `uvm_component_utils(i2c_driver)


    function new(string name = "i2c_driver", uvm_component c);
        super.new(name, c);
    endfunction

    i2c_seq_item tr;
    virtual i2c_intf i2c_if;

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tr = i2c_seq_item::type_id::create("TRANSACTION");
        if (!uvm_config_db#(virtual i2c_intf)::get(this, "", "i2c_if", i2c_if)) begin
            `uvm_fatal("DRV", "VIF not set in config DB (Field: i2c_if)")
        end
    endfunction

    task run_phase(uvm_phase phase);
        #10;
        forever begin
            seq_item_port.get_next_item(tr);

            //Drive Address + R/W bit
            i2c_if.tx_data_m  <= {tr.SLAVE_ADDR, tr.rw_bit};
            i2c_if.i2c_enable <= 1'b1;
            i2c_if.i2c_start  <= 1'b1;
            i2c_if.i2c_stop   <= 1'b0;


            // repeat (10_000) @(posedge i2c_if.clk);
            @(posedge i2c_if.tx_done_m);
            i2c_if.i2c_start <= 1'b0;
            i2c_if.i2c_enable = 1'b0;
            i2c_if.tx_data_m <= tr.data;

            // 4. Wait for WRITE transaction completion
            // @(posedge i2c_if.tx_done_m);
            // repeat (9_000) @(posedge i2c_if.clk);
            @(posedge i2c_if.tx_done_m);

            `uvm_info("DRV", $sformatf("Write done for Data=%0h", i2c_if.tx_data_m), UVM_NONE)

            // 5. Drive STOP
            i2c_if.i2c_stop = 1'b1;
            repeat (1_200) @(posedge i2c_if.clk);
            i2c_if.i2c_stop = 1'b0;
            // 6. Item completion
            seq_item_port.item_done();
        end
    endtask
endclass  // i2c_driver


////////////////////////////////////////////////////////////////////////////////
//
// 5. MONITOR: Master Output Sampling (Write Only)
//
////////////////////////////////////////////////////////////////////////////////

class i2c_monitor extends uvm_monitor;
    `uvm_component_utils(i2c_monitor)
    uvm_analysis_port #(i2c_seq_item) send;


    function new(string name = "MON", uvm_component parent);
        super.new(name, parent);
        send = new("Write", this);
    endfunction

    i2c_seq_item tr;
    virtual i2c_intf i2c_if;

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tr = i2c_seq_item::type_id::create("TRANSACTION");
        if (!uvm_config_db#(virtual i2c_intf)::get(this, "", "i2c_if", i2c_if)) begin
            `uvm_fatal("MON", "VIF not set in config DB (Field: i2c_if)")
        end
    endfunction

    task run_phase(uvm_phase phase);
        #10;
        forever begin
            // Wait for slave rx_done 
            // repeat (20_000) @(posedge i2c_if.clk);
            @(posedge i2c_if.rx_done_s);
            @(posedge i2c_if.rx_done_s);

            tr.s_data = i2c_if.rx_data_s;
            tr.data   = i2c_if.tx_data_m;
            `uvm_info("MON", $sformatf("Monitored WRITE completion, Last tx_data_m=%0h", i2c_if.rx_data_s), UVM_NONE)

            // Analysis Port를 통해 Scoreboard의 write 함수를 호출
            send.write(tr);
        end
    endtask
endclass  // i2c_monitor


////////////////////////////////////////////////////////////////////////////////
//
// 6. AGENT, ENV, TEST: Hierarchy and Structure (Write Only)
//
////////////////////////////////////////////////////////////////////////////////

class i2c_agent extends uvm_agent;
    `uvm_component_utils(i2c_agent)

    function new(string name = "AGENT", uvm_component parent);
        super.new(name, parent);
    endfunction

    i2c_driver drv;
    i2c_monitor mon;
    uvm_sequencer #(i2c_seq_item) sqr;


    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = i2c_driver::type_id::create("DRV", this);
        mon = i2c_monitor::type_id::create("MON", this);
        sqr = uvm_sequencer#(i2c_seq_item)::type_id::create("SQR", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass

////////////////////////////////////////////////////////////////////////////////
//
// 7. SCOREBOARD: Verification Logic (Analysis TLM Pattern 적용)
//
////////////////////////////////////////////////////////////////////////////////

class i2c_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(i2c_scoreboard)
    uvm_analysis_imp #(i2c_seq_item, i2c_scoreboard) recv;
    i2c_seq_item tr;
    int write_pass_cnt = 0;
    int write_fail_cnt = 0;

    function new(string name = "SCB", uvm_component parent);
        super.new(name, parent);
        recv = new("Read", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tr = i2c_seq_item::type_id::create("TRANSACTION");
    endfunction

    // ** Analysis TLM 핵심: Monitor.write() 호출 시 이 함수가 즉시 실행됨 (function)**
    function void write(input i2c_seq_item mon_tr);
        tr = mon_tr;
        `uvm_info("SCB", $sformatf("DATA received from Monitor Master tx_data:%0h, slave rx_data:%0h:", tr.data, tr.s_data), UVM_NONE)
        tr.print(uvm_default_line_printer);

        if (tr.data == tr.s_data) begin
            `uvm_info("SCB", "Test Passed", UVM_NONE)
            write_pass_cnt++;
        end else begin
            `uvm_error("SCB", "Test Failed")
            write_fail_cnt++;
        end

    endfunction


    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SCB", $sformatf("\n\n--------------------------------\n\
--- I2C Verification Summary ---\n--------------------------------\n\
--- Total Transactions: %3d  ---\n\
---    Tests Passed: %3d     ---\n\
---    Tests Failed: %3d     ---\n\
--------------------------------\n\
--------------------------------\n\
--------------------------------\n", write_pass_cnt + write_fail_cnt, write_pass_cnt, write_fail_cnt), UVM_NONE)
    endfunction

endclass  // i2c_scoreboard


class i2c_env extends uvm_env;
    `uvm_component_utils(i2c_env)

    function new(string name = "i2c_env", uvm_component parent);
        super.new(name, parent);
    endfunction

    i2c_agent agt;
    i2c_scoreboard scb;


    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = i2c_agent::type_id::create("AGT", this);
        scb = i2c_scoreboard::type_id::create("SCB", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.mon.send.connect(scb.recv);
    endfunction
endclass  // i2c_env

class i2c_write_test extends uvm_test;
    `uvm_component_utils(i2c_write_test)

    function new(string name = "i2c_write_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    i2c_env env;
    i2c_write_sequence seq;


    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        seq = i2c_write_sequence::type_id::create("SEQ", this);
        env = i2c_env::type_id::create("ENV", this);
    endfunction

    function void start_of_simulation_phase(uvm_phase phase);
        super.start_of_simulation_phase(phase);
        uvm_root::get().print_topology();
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        seq.start(env.agt.sqr);
        phase.drop_objection(this);

    endtask
endclass  // i2c_write_test

////////////////////////////////////////////////////////////////////////////////
//
// 8. TOP MODULE: Testbench Harness (Instantiates DUTs for simulation)
//
////////////////////////////////////////////////////////////////////////////////

module tb_i2c;
    logic clk;
    logic reset;


    i2c_intf i2c_if (
        clk,
        reset
    );

    // wire sda_bus;
    // assign sda_bus = i2c_if.sda_wire;

    // 1. Master DUT 인스턴스화 및 연결 (DUT 정의는 Makefile을 통해 ./rtl/i2c_master.sv에서 컴파일됨)
    i2c_master master_dut (
        .clk(i2c_if.clk),
        .reset(i2c_if.reset),
        .i2c_start(i2c_if.i2c_start),
        .i2c_stop(i2c_if.i2c_stop),
        .i2c_enable(i2c_if.i2c_enable),
        .tx_data(i2c_if.tx_data_m),
        .tx_ready(i2c_if.tx_ready_m),
        .tx_done(i2c_if.tx_done_m),
        .rx_data(i2c_if.rx_data_m),
        .rx_done(i2c_if.rx_done_m),
        .scl(i2c_if.scl),
        .sda(i2c_if.sda)
    );

    // 2. Slave DUT 인스턴스화 및 연결 (DUT 정의는 Makefile을 통해 ./rtl/i2c_slave.sv에서 컴파일됨)
    i2c_slave slave_dut (
        .clk(i2c_if.clk),
        .reset(i2c_if.reset),
        .scl(i2c_if.scl),
        .sda(i2c_if.sda),
        .tx_data(8'h0),
        .tx_ready(i2c_if.tx_ready_s),
        .tx_done(i2c_if.tx_done_s),
        .rx_data(i2c_if.rx_data_s),
        .rx_done(i2c_if.rx_done_s)
    );

    always #5 clk = ~clk;

    // 3. UVM Config DB 설정
    initial begin
        $fsdbDumpvars(0);
        $fsdbDumpfile("wave.fsdb");

        clk   = 0;
        reset = 1;
        // i2c_if.sda_wire = 1'bZ;
        #10;
        reset = 0;
    end

    // 리셋 및 UVM 실행
    initial begin
        uvm_config_db#(virtual i2c_intf)::set(null, "*", "i2c_if", i2c_if);
        // repeat(5)@(posedge clk);
        run_test();
        #10;
        $finish;
    end

endmodule
