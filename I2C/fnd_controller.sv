`timescale 1ns / 1ps


module fnd_controller (
    input  logic       clk,
    input  logic       rst,
    input  logic       start,
    input  logic [7:0] rx_data,
    input  logic       rx_done,
    output logic [3:0] fnd_com,
    output logic [7:0] fnd_data
);
    logic w_clk_1khz;
    logic [1:0] w_sel;
    logic [3:0] w_digit_1, w_digit_10, w_digit_100, w_digit_1000;
    logic [3:0] w_bcd;

    clk_divider U_CLK_DIV (
        .clk(clk),
        .rst(rst),
        .clk_1khz(w_clk_1khz)
    );

    counter_4 U_COUNTER_4 (
        .clk(w_clk_1khz),
        .rst(rst),
        .sel(w_sel)
    );

    decoder_2x4 U_DECODER_2X4 (
        .sel(w_sel),
        .fnd_com(fnd_com)
    );
    // digit_splitter U_DIGIT_SPLIT (
    //     .count(counter),
    //     .digit_1(w_digit_1),
    //     .digit_10(w_digit_10),
    //     .digit_100(w_digit_100),
    //     .digit_1000(w_digit_1000)
    // );

    i2c_fnd_recv U_I2C_RECV (
        .clk       (clk),
        .reset     (rst),
        .rx_data   (rx_data),
        .rx_done   (rx_done),
        .start     (start),
        .digit_1000(w_digit_1000),
        .digit_100 (w_digit_100),
        .digit_10  (w_digit_10),
        .digit_1   (w_digit_1)
    );
    mux_4x1 U_MUX_4X1 (
        .digit_1(w_digit_1),
        .digit_10(w_digit_10),
        .digit_100(w_digit_100),
        .digit_1000(w_digit_1000),
        .sel(w_sel),
        .bcd(w_bcd)
    );
    bcd_decoder U_BCD (
        .bcd(w_bcd),
        .fnd_data(fnd_data)
    );


endmodule


module i2c_fnd_recv (
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] rx_data,
    input  logic       rx_done,
    input  logic       start,
    output logic [3:0] digit_1000,
    output logic [3:0] digit_100,
    output logic [3:0] digit_10,
    output logic [3:0] digit_1
);

    typedef enum {
        IDLE,
        DATA
    } state_e;

    state_e state, state_next;
    logic trig, trig_next;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state      <= IDLE;
            digit_1000 <= 0;
            digit_100  <= 0;
            digit_10   <= 0;
            digit_1    <= 0;
            trig       <= 0;
        end else begin
            state <= state_next;
            trig  <= trig_next;
            if (trig) begin
                digit_1000 <= digit_100;
                digit_100  <= digit_10;
                digit_10   <= digit_1;
                digit_1    <= rx_data[3:0];

            end
        end
    end

    always_comb begin
        state_next = state;
        trig_next  = trig;
        case (state)
            IDLE: begin
                trig_next = 0;
                if (start) begin
                    state_next = DATA;
                end
            end
            DATA: begin
                if (rx_done) begin
                    state_next = IDLE;
                    trig_next  = 1;
                end
            end
        endcase
    end
endmodule


module mux_4x1 (
    input  logic [3:0] digit_1,
    input  logic [3:0] digit_10,
    input  logic [3:0] digit_100,
    input  logic [3:0] digit_1000,
    input  logic [1:0] sel,
    output logic [3:0] bcd
);
    reg [3:0] bcd_reg;
    assign bcd = bcd_reg;
    always_comb begin
        case (sel)
            2'b00:   bcd_reg = digit_1;
            2'b01:   bcd_reg = digit_10;
            2'b10:   bcd_reg = digit_100;
            2'b11:   bcd_reg = digit_1000;
            default: bcd_reg = digit_1;
        endcase
    end

endmodule

// module digit_splitter (
//     input  logic [13:0] count,
//     output logic [ 3:0] digit_1,
//     output logic [ 3:0] digit_10,
//     output logic [ 3:0] digit_100,
//     output logic [ 3:0] digit_1000
// );
//     always_comb begin
//         digit_1    = count % 10;
//         digit_10   = (count / 10) % 10;
//         digit_100  = (count / 100) % 10;
//         digit_1000 = (count / 1000)%10;
//     end
// endmodule

module decoder_2x4 (
    input  logic [1:0] sel,
    output logic [3:0] fnd_com
);
    always_comb begin
        case (sel)
            2'b00:   fnd_com = 4'b1110;
            2'b01:   fnd_com = 4'b1101;
            2'b10:   fnd_com = 4'b1011;
            2'b11:   fnd_com = 4'b0111;
            default: fnd_com = 4'b1111;
        endcase
    end

endmodule

module counter_4 (
    input  logic       clk,
    input  logic       rst,
    output logic [1:0] sel
);
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            sel <= 2'b00;
        end else begin
            if (sel == 3) begin
                sel <= 0;
            end else begin
                sel <= sel + 2'b01;
            end
        end
    end
endmodule

module clk_divider (
    input  logic clk,
    input  logic rst,
    output logic clk_1khz
);
    logic [$clog2(100_000)-1:0] r_count;
    logic o_clk;

    assign clk_1khz = o_clk;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            r_count <= 0;
            o_clk   <= 0;
        end else begin
            if (r_count == 100_000 - 1) begin
                r_count <= 0;
                o_clk   <= 1;
            end else begin
                r_count <= r_count + 1;
                if (r_count == 100_000 / 2 - 1) begin
                    o_clk <= 0;
                end
            end
        end
    end

endmodule

module bcd_decoder (
    input  logic [3:0] bcd,
    output logic [7:0] fnd_data
);

    always_comb begin
        case (bcd)
            4'b0000: fnd_data = 8'hc0;
            4'b0001: fnd_data = 8'hf9;
            4'b0010: fnd_data = 8'ha4;
            4'b0011: fnd_data = 8'hb0;
            4'b0100: fnd_data = 8'h99;
            4'b0101: fnd_data = 8'h92;
            4'b0110: fnd_data = 8'h82;
            4'b0111: fnd_data = 8'hf8;
            4'b1000: fnd_data = 8'h80;
            4'b1001: fnd_data = 8'h90;
            // 4'b1010: fnd_data = 8'h88;
            // 4'b1011: fnd_data = 8'h83;
            // 4'b1100: fnd_data = 8'hc6;
            // 4'b1101: fnd_data = 8'ha1;
            // 4'b1110: fnd_data = 8'h7f;
            // 4'b1111: fnd_data = 8'hff;
            default: fnd_data = 8'hff;
        endcase
    end


endmodule
