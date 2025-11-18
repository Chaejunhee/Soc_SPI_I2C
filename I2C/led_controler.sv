`timescale 1ns / 1ps


module led_controler (
    input  logic       clk,
    input  logic       reset,
    input  logic       start,
    input  logic [7:0] rx_data,
    input  logic       rx_done,
    output logic [7:0] led
);


    typedef enum {
        IDLE,
        DATA
    } state_e;

    state_e state, state_next;
    logic [7:0] led_reg, led_next;

    assign led = led_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state   <= IDLE;
            led_reg <= 0;
        end else begin
            state   <= state_next;
            led_reg <= led_next;
        end
    end

    always_comb begin
        state_next = state;
        led_next   = led_reg;
        case (state)
            IDLE: begin
                if (start) begin
                    state_next = DATA;
                end
            end
            DATA: begin
                if (rx_done) begin
                    led_next   = rx_data;
                    state_next = IDLE;
                end
            end
        endcase
    end
endmodule
