`timescale 1ns / 1ps


module I2C_fnd_slave (
    //global signals
    input  logic       clk,
    input  logic       reset,
    //external ports,
    input  logic       scl,
    // input  logic       sda,
    inout  logic       sda,
    //internal signals
    input  logic [7:0] tx_data,
    output logic       tx_ready,
    output logic       tx_done,
    output logic [7:0] rx_data,
    output logic       rx_done,
    output logic       start
);
    //////////////scl edge detection/////////////
    logic scl_sync1, scl_sync2;
    logic scl_rising_edge, scl_falling_edge;
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            scl_sync1 <= 0;
            scl_sync2 <= 0;
        end else begin
            scl_sync1 <= scl;
            scl_sync2 <= scl_sync1;
        end
    end
    assign scl_rising_edge  = scl_sync1 & ~scl_sync2;
    assign scl_falling_edge = ~scl_sync1 & scl_sync2;
    //////////////////////////////////////////////////


    typedef enum {
        IDLE,
        ADDR,
        READ,
        WRITE,
        ACK1,
        ACK2,
        ACK3,
        // ACK4,
        DACK1,
        DACK2,
        DACK3,
        DACK4,
        STOP
    } state_e;

    state_e state, state_next;

    logic sda_out_en, sda_out_en_next;
    logic sda_write_reg, sda_write_next;
    logic [7:0] rx_data_reg, rx_data_next;
    logic [2:0] bit_cnt_reg, bit_cnt_next;
    logic [7:0] addr_next, addr_reg;

    logic [1:0] byte_data_cnt, byte_data_cnt_next;

    // assign sda = sda_out_en ? sda_write_reg : 1'bz;
    assign rx_data = rx_data_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state         <= IDLE;
            sda_out_en    <= 1'b0;
            sda_write_reg <= 0;
            rx_data_reg   <= 0;
            bit_cnt_reg   <= 0;
            addr_reg      <= 0;
            byte_data_cnt <= 0;
        end else begin
            state         <= state_next;
            sda_out_en    <= sda_out_en_next;
            sda_write_reg <= sda_write_next;
            rx_data_reg   <= rx_data_next;
            bit_cnt_reg   <= bit_cnt_next;
            addr_reg      <= addr_next;
            byte_data_cnt <= byte_data_cnt_next;
        end
    end

    always_comb begin
        state_next         = state;
        sda_out_en_next    = sda_out_en;
        sda_write_next     = sda_write_reg;
        rx_data_next       = rx_data_reg;
        bit_cnt_next       = bit_cnt_reg;
        addr_next          = addr_reg;
        rx_done            = 1'b0;
        byte_data_cnt_next = byte_data_cnt;
        start              = 0;
        case (state)
            IDLE: begin
                sda_out_en_next = 1'b0;
                byte_data_cnt_next = 0;
                if (scl && ~sda) begin
                    state_next   = ADDR;
                    bit_cnt_next = 0;
                end
            end
            ADDR: begin
                sda_out_en_next = 1'b0;
                if (scl_rising_edge) begin
                    addr_next = {addr_reg[6:0], sda};
                    if (bit_cnt_reg == 7) begin
                        bit_cnt_next = 0;
                        state_next   = ACK1;
                    end else begin
                        bit_cnt_next = bit_cnt_reg + 1;
                    end
                end
            end
            ACK1: begin
                if (scl_falling_edge) begin
                    state_next = ACK2;
                end
            end
            ACK2: begin
                sda_out_en_next = 1'b0;
                sda_write_next  = 1'b0;
                if (scl_rising_edge) begin
                    state_next = ACK3;
                end
            end
            ACK3: begin
                // sda_out_en_next = 1'b1;
                sda_out_en_next = 1'b0;
                sda_write_next  = 1'b0;
                if (scl_falling_edge) begin
                    // state_next = ACK4;
                    sda_out_en_next = 1'b0;
                    rx_done = 1'b1;
                    if (addr_reg[7:1] == 7'b1110000) begin
                        state_next = READ;
                        start = 1;
                    end else begin
                        state_next = IDLE;
                        addr_next   = 0;
                    end

                end
            end
            READ: begin
                if (scl_rising_edge) begin
                    rx_data_next = {rx_data_reg[6:0], sda};
                    if (bit_cnt_reg == 7) begin
                        bit_cnt_next = 0;
                        // rx_data_next = 1'b1;
                        state_next   = DACK1;
                    end else begin
                        bit_cnt_next = bit_cnt_reg + 1;
                    end
                end
            end
            DACK1: begin
                if (scl_falling_edge) begin
                    state_next = DACK2;
                end
            end
            DACK2: begin
                sda_out_en_next = 1'b1;
                sda_write_next  = 1'b0;
                if (scl_rising_edge) begin
                    state_next = DACK3;
                end
            end
            DACK3: begin
                sda_out_en_next = 1'b1;
                sda_write_next  = 1'b0;
                if (scl_falling_edge) begin
                    state_next = DACK4;
                end
            end
            DACK4: begin
                sda_out_en_next = 1'b1;
                sda_write_next  = 1'b0;
                if (scl_rising_edge) begin
                    rx_done = 1'b1;
                    // if (byte_data_cnt == 3) begin
                    //     state_next = STOP;
                    //     byte_data_cnt_next =0;
                    // end else begin
                    //     state_next = READ;
                    //     // rx_data_next=0;
                    //     byte_data_cnt_next = byte_data_cnt + 1;
                    // end
                    state_next = STOP;
                    sda_out_en_next = 1'b0;
                end
            end
            STOP: begin
                if (sda && scl) begin
                    state_next = IDLE;
                end
            end


        endcase
    end

endmodule
