`timescale 1ns / 1ps

module Slave (
    //global signals
    input logic clk,
    input logic reset,
    //external signals
    input logic sclk,
    input logic mosi,
    input logic ss,
    output logic [3:0] fnd_com,
    output logic [7:0] fnd_data
);

//////////////////////////////
    logic si_done;
    logic [7:0] si_data;
    logic [13:0] counter;

    spi_slave U_SPI_SLAVE (
        .*,
        .miso(),
        .cs(ss),
        .so_data(),
        .so_start(),
        .so_ready()

    );

    control_unit U_CU (
        .*,
        .count_data(counter)
    );

    fnd_controller U_FND_CONTROLLER (
        .clk     (clk),
        .rst     (reset),
        .counter (counter),
        .fnd_com (fnd_com),
        .fnd_data(fnd_data)
    );
endmodule

module control_unit (
    input  logic        clk,
    input  logic        reset,
    input  logic [ 7:0] si_data,
    input  logic        si_done,
    output logic [13:0] count_data
);
    logic [15:0] data_reg, data_next;
    logic [7:0] upperdata_reg, upperdata_next;
    logic [7:0] downdata_reg, downdata_next;

    typedef enum {
        UPPERBIT,
        DOWNBIT,
        UPDATE
    } state_e;

    state_e state, state_next;

    assign count_data = data_reg[13:0];

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state         <= UPPERBIT;
            data_reg      <= 0;
            upperdata_reg <= 0;
            downdata_reg  <= 0;
        end else begin
            state         <= state_next;
            data_reg      <= data_next;
            upperdata_reg <= upperdata_next;
            downdata_reg  <= downdata_next;
        end
    end

    always_comb begin
        state_next     = state;
        data_next      = data_reg;
        upperdata_next = upperdata_reg;
        downdata_next  = downdata_reg;
        case (state)
            UPPERBIT: begin
                if (si_done) begin
                    upperdata_next = si_data;
                    state_next = DOWNBIT;
                end
            end
            DOWNBIT: begin
                if (si_done) begin
                    downdata_next = si_data;
                    state_next = UPDATE;
                end
            end
            UPDATE: begin
                data_next  = {upperdata_reg, downdata_reg};
                state_next = UPPERBIT;
            end
        endcase
    end
endmodule
