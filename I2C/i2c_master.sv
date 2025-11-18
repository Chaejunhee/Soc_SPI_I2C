`timescale 1ns / 1ps


module i2c_master (
    //global signals
    input  logic       clk,
    input  logic       reset,
    //master internal signals
    input  logic       i2c_start,
    input  logic       i2c_stop,
    input  logic       i2c_enable,
    // input  logic       i2c_ack,
    // input  logic       i2c_nack,
    input  logic [7:0] tx_data,
    output logic       tx_ready,
    output logic       tx_done,
    output logic [7:0] rx_data,
    output logic       rx_done,
    //external
    output logic       scl,
    inout  logic       sda
);
    typedef enum {
        IDLE,
        START1,
        START2,
        DATA1,
        DATA2,
        DATA3,
        DATA4,
        ACK1,
        ACK2,
        ACK3,
        ACK4,
        HOLD,
        STOP1,
        STOP2
    } state_e;

    state_e state, state_next;

    typedef enum {
        READ,
        WRITE
    } rw_state_e;

    rw_state_e rw_state, rw_state_next;

    logic sda_write_reg, sda_write_next;  //sda 슬레이브로 보내는 레지스터
    logic ack_reg;
    logic [7:0] tx_data_reg, tx_data_next;
    logic [7:0] rx_data_reg, rx_data_next;
    logic [$clog2(500)-1:0] clk_counter_reg, clk_counter_next;
    logic [2:0] bit_cnt_reg, bit_cnt_next;
    logic sda_out_en, sda_out_en_next;
    logic addr_flag, addr_flag_next;
    logic scl_reg, scl_next;

    assign sda = (sda_out_en) ? sda_write_reg : 1'bz;
    assign tx_ready = (state == IDLE || state == HOLD) ? 1'b1 : 1'b0;
    assign rx_data = rx_data_reg;
    assign scl = scl_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state           <= IDLE;  // reset logic
            rw_state        <= WRITE;
            clk_counter_reg <= 0;
            tx_data_reg     <= 8'b0;
            rx_data_reg     <= 8'b0;
            bit_cnt_reg     <= 0;
            addr_flag       <= 0;
            sda_out_en      <= 1'b1;
            scl_reg         <= 1'b1;
            sda_write_reg   <= 1'b1;
            ack_reg         <= 0;
        end else begin
            // state machine logic
            state           <= state_next;
            rw_state        <= rw_state_next;
            clk_counter_reg <= clk_counter_next;
            tx_data_reg     <= tx_data_next;
            rx_data_reg     <= rx_data_next;
            bit_cnt_reg     <= bit_cnt_next;
            addr_flag       <= addr_flag_next;
            sda_out_en      <= sda_out_en_next;
            scl_reg         <= scl_next;
            sda_write_reg   <= sda_write_next;
        end
    end

    always_comb begin
        state_next       = state;
        rw_state_next    = rw_state;
        clk_counter_next = clk_counter_reg;
        tx_data_next     = tx_data_reg;
        rx_data_next     = rx_data_reg;
        bit_cnt_next     = bit_cnt_reg;
        addr_flag_next   = addr_flag;
        sda_out_en_next  = sda_out_en;
        scl_next         = scl_reg;
        sda_write_next   = sda_write_reg;
        tx_done          = 1'b0;
        rx_done          = 1'b0;
        case (state)
            IDLE: begin
                sda_out_en_next = 1'b1;
                sda_write_next = 1'b1;
                scl_next = 1'b1;
                if (i2c_enable && i2c_start) begin
                    state_next = HOLD;
                end
            end
            ////////////////HOLD//////////////////////
            HOLD: begin
                sda_out_en_next = 1'b1;
                sda_write_next = sda_write_reg;
                scl_next = scl_reg;
                if (i2c_start & ~i2c_stop) begin  //start 주소 보내기
                    state_next = START1;
                    tx_data_next = tx_data;
                    rw_state_next = WRITE;
                end else if (~i2c_start & i2c_stop) begin  //stop
                    state_next = STOP1;
                end else if (~i2c_start & ~i2c_stop) begin  //write data
                    state_next = DATA1;
                    tx_data_next = tx_data;
                    rw_state_next = WRITE;
                end else if (i2c_start & i2c_stop) begin
                    state_next = DATA1;
                    rw_state_next = READ;
                end

            end
            ////////////////////////////////////////

            ///////////////////START///////////////////////
            START1: begin
                addr_flag_next = 1'b1;
                sda_out_en_next = 1'b1;
                sda_write_next = 1'b0;
                scl_next = 1'b1;
                if (clk_counter_reg == 499) begin
                    clk_counter_next = 0;
                    state_next = START2;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end
            START2: begin
                sda_out_en_next = 1'b1;
                sda_write_next = 1'b0;
                scl_next = 1'b0;
                if (clk_counter_reg == 499) begin
                    clk_counter_next = 0;
                    state_next = DATA1;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end
            //////////////////////////////////////////////

            ////////////////////DATA//////////////////////
            DATA1: begin
                case (rw_state)
                    WRITE: begin
                        sda_out_en_next = 1'b1;
                        sda_write_next  = tx_data_reg[7];
                    end
                    READ: begin
                        sda_out_en_next = 1'b0;
                        sda_write_next  = 0;
                    end
                endcase
                scl_next = 1'b0;
                if (clk_counter_reg == 249) begin
                    clk_counter_next = 0;
                    state_next = DATA2;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end
            DATA2: begin
                case (rw_state)
                    WRITE: begin
                        sda_out_en_next = 1'b1;
                        sda_write_next  = tx_data_reg[7];
                    end
                    READ: begin
                        sda_out_en_next = 1'b0;
                        sda_write_next  = 1'b0;
                    end
                endcase
                scl_next = 1'b1;
                if (clk_counter_reg == 249) begin
                    clk_counter_next = 0;
                    if (rw_state == READ) begin
                        rx_data_next = {rx_data_reg[6:0], sda};
                    end
                    state_next = DATA3;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end
            DATA3: begin
                case (rw_state)
                    WRITE: begin
                        sda_out_en_next = 1'b1;
                        sda_write_next  = tx_data_reg[7];
                    end
                    READ: begin
                        sda_out_en_next = 1'b0;
                        sda_write_next  = 1'b0;
                    end
                endcase
                scl_next = 1'b1;
                if (clk_counter_reg == 249) begin
                    clk_counter_next = 0;
                    state_next = DATA4;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end
            DATA4: begin
                case (rw_state)
                    WRITE: begin
                        sda_out_en_next = 1'b1;
                        sda_write_next  = tx_data_reg[7];
                    end
                    READ: begin
                        sda_out_en_next = 1'b0;
                        sda_write_next  = 1'b0;
                    end
                endcase
                scl_next = 0;
                if (clk_counter_reg == 249) begin
                    clk_counter_next = 0;
                    if (bit_cnt_reg == 7) begin
                        bit_cnt_next = 0;
                        state_next   = ACK1;
                    end else begin
                        bit_cnt_next = bit_cnt_reg + 1;
                        tx_data_next = {tx_data_reg[6:0], 1'b0};
                        state_next   = DATA1;
                    end
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end
            /////////////////////////////////////////////////////

            ///////////////////////ACK//////////////////////////
            ACK1: begin
                case (rw_state)
                    WRITE: begin
                        sda_out_en_next = 1'b0;
                        sda_write_next  = 1'b0;
                    end
                    READ: begin
                        sda_out_en_next = 1'b1;
                        sda_write_next  = 1'b0;
                    end
                endcase
                scl_next = 1'b0;
                if (clk_counter_reg == 249) begin
                    clk_counter_next = 0;
                    state_next = ACK2;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end
            ACK2: begin
                case (rw_state)
                    WRITE: begin
                        sda_out_en_next = 1'b0;
                        sda_write_next  = 1'b0;
                    end
                    READ: begin
                        sda_out_en_next = 1'b1;
                        sda_write_next  = 1'b1;
                    end
                endcase
                scl_next = 1'b1;
                if (clk_counter_reg == 249) begin
                    clk_counter_next = 0;
                    ack_reg = sda;  //ack 읽기
                    state_next = ACK3;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end
            ACK3: begin
                case (rw_state)
                    WRITE: begin
                        sda_out_en_next = 1'b0;
                        sda_write_next  = 1'b0;
                    end
                    READ: begin
                        sda_out_en_next = 1'b1;
                        sda_write_next  = 1'b1;
                    end
                endcase
                scl_next = 1'b1;
                if (clk_counter_reg == 249) begin
                    clk_counter_next = 0;
                    state_next = ACK4;
                    if (rw_state == WRITE /*&& ack_reg == 0*/) begin
                        tx_done = 1'b1;
                        addr_flag_next = 1'b0;
                    end else if (rw_state == READ) begin
                        rx_done = 1'b1;
                    end
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end
            ACK4: begin
                case (rw_state)
                    WRITE: begin
                        sda_out_en_next = 1'b0;
                        sda_write_next  = 1'b0;
                    end
                    READ: begin
                        sda_out_en_next = 1'b1;
                        sda_write_next  = 1'b0;
                    end
                endcase
                scl_next = 1'b0;
                if (clk_counter_reg == 249) begin
                    clk_counter_next = 0;
                    state_next = HOLD;


                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end
            ////////////////////////////////////////////////

            ///////////////////STOP////////////////////
            STOP1: begin
                sda_out_en_next = 1'b1;
                sda_write_next = 1'b0;
                scl_next = 1'b1;
                if (clk_counter_reg == 499) begin
                    clk_counter_next = 0;
                    state_next = STOP2;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end
            STOP2: begin
                sda_out_en_next = 1'b1;
                sda_write_next = 1'b1;
                scl_next = 1'b1;
                if (clk_counter_reg == 499) begin
                    clk_counter_next = 0;
                    state_next = IDLE;
                end else begin
                    clk_counter_next = clk_counter_reg + 1;
                end
            end


            ////////////////////////////////////////////
        endcase
    end


endmodule
