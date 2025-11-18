`timescale 1ns / 1ps

module top (
    input  logic       clk,
    input  logic       reset,
    //external
    input  logic       run,
    input  logic       stop,
    input  logic       clear,
    output logic [3:0] fnd_com,
    output logic [7:0] fnd_data,
    //master 
    output logic       sclk_m,
    output logic       mosi_m,
    output logic       ss_m,
    //slave
    input  logic       sclk_s,
    input  logic       mosi_s,
    input  logic       ss_s

);


    Master U_Master (
        .*,
        .run  (run),
        .stop (stop),
        .clear(clear),
        .sclk (sclk_m),
        .mosi (mosi_m),
        .ss   (ss_m)
    );

    Slave U_Slave (
        .*,
        .sclk(sclk_s),
        .mosi(mosi_s),
        .ss  (ss_s)
    );


endmodule


